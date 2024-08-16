# frozen_string_literal: true

require "webhookdb/jobs/webhook_subscription_delivery_event"

# Webhook subscriptions have a few parts:
#
# - The WebhookSubscription itself (this model),
#   which represents a user's desire to receive all webhooks at a URL.
# - The individual Delivery, which is a single 'rowupsert' event being
#   delivered to a subscription.
#   That is, if multiple rowupserts are done, there will be multiple Deliveries
#   to a single Subscription, one for each rowupsert.
#   Likewise, if a single rowupsert is done, but there are multiple Subscriptions,
#   there will be multiple Deliveries, one to each Subscription.
# - Async job that listens for rowupsert events and enqueues new deliveries.
# - When a delivery is 'enqueued', it is created in the database,
#   and then a sidekiq job is put into Redis.
#   This sidekiq job operates OUTSIDE of our normal job system
#   since we do not want to bother with audit logging or routing
#   (enough history is in the DB already, though we could add it if needed).
# - We attempt the delivery until it succeeds, or we run out of attempts.
#   See #attempt_delivery.
#
class Webhookdb::WebhookSubscription < Webhookdb::Postgres::Model(:webhook_subscriptions)
  plugin :timestamps
  plugin :text_searchable, terms: [:organization, :service_integration, :deliver_to_url, :created_by]
  plugin :column_encryption do |enc|
    enc.column :webhook_secret
  end

  many_to_one :service_integration, class: Webhookdb::ServiceIntegration
  many_to_one :organization, class: Webhookdb::Organization
  many_to_one :created_by, class: Webhookdb::Customer

  # Amount of time we wait for a response from the server.
  TIMEOUT = 10.seconds
  # An individual will be delivered this many times before giving up.
  MAX_DELIVERY_ATTEMPTS = 25

  dataset_module do
    def active
      return self.where(deactivated_at: nil)
    end

    def to_notify
      return self.active
    end
  end

  def active?
    return !self.deactivated?
  end

  def deactivated?
    return !!self.deactivated_at
  end

  def deactivate(at: Time.now)
    self.deactivated_at = at
    return self
  end

  def fetch_organization
    return self.organization || self.service_integration.organization
  end

  def status
    return self.deactivated? ? "deactivated" : "active"
  end

  # Deliver the webhook payload to the configured URL.
  # This does NOT create or deal with WebhookSubscription::Delivery;
  # it is for the actual delivering.
  def deliver(service_name:, table_name:, row:, external_id:, external_id_column:, headers: {})
    body = {
      service_name:,
      table_name:,
      row:,
      external_id:,
      external_id_column:,
    }
    return Webhookdb::Http.post(
      self.deliver_to_url,
      body,
      headers: {"Whdb-Webhook-Secret" => self.webhook_secret}.merge(headers),
      timeout: TIMEOUT,
      logger: self.logger,
    )
  end

  def deliver_test_event(external_id: SecureRandom.hex(6))
    return self.deliver(
      service_name: "test service",
      table_name: "test_table_name",
      external_id:,
      external_id_column: "external_id",
      row: {data: ["alpha", "beta", "charlie", "delta"]},
      headers: {"Whdb-Test-Event" => "1"},
    )
  end

  def create_delivery(payload)
    return Webhookdb::WebhookSubscription::Delivery.create(webhook_subscription: self, payload:)
  end

  # Create a new Delivery and enqueue it for async processing.
  def enqueue_delivery(payload)
    delivery = self.create_delivery(payload)
    Webhookdb::Jobs::WebhookSubscriptionDeliveryEvent.perform_async(delivery.id)
    return delivery
  end

  # Attempt to deliver the payload in +d+ to the configured URL (see #deliver).
  # Noops if the subscription is deactivated.
  #
  # If the attempt succeeds, no attempts are enqueued.
  #
  # If the attempt fails, another async job to reattempt delivery
  # will be enqueued for some time in the future based on the number of attempts.
  # The timestamp and http status are stored on the delivery for future analysis.
  #
  # After too many failures, no more attempts will be enqueued.
  # Instead, a developer alert is emitted.
  #
  # In the future, we will support manually re-attempting delivery (success of which should
  # clear deactivated subscriptions), and automatic deactivation
  # (after some criteria of abandonment has been met).
  def attempt_delivery(d)
    return if self.deactivated?
    d.db.transaction do
      d.lock!
      attempt = d.attempt_count + 1
      begin
        r = self.deliver(**d.payload.symbolize_keys, headers: {"Whdb-Attempt" => attempt.to_s})
        d.add_attempt(status: r.code)
      rescue StandardError => e
        self.logger.error(
          "webhook_subscription_delivery_failure",
          error: e,
          webhook_subscription_id: self.id,
          webhook_subscription_delivery_id: d.id,
        )
        d.add_attempt(status: e.is_a?(Webhookdb::Http::Error) ? e.status : 0)
        if attempt < MAX_DELIVERY_ATTEMPTS
          self._retry(d, attempt)
        else
          self._fatal(d, e)
        end
      ensure
        d.save_changes
      end
    end
  end

  def _retry(delivery, attempt)
    delay = self.class.backoff_for_attempt(attempt)
    Webhookdb::Jobs::WebhookSubscriptionDeliveryEvent.perform_in(delay, delivery.id)
  end

  def self.backoff_for_attempt(attempt)
    return 1 if attempt <= 1
    return attempt * 2 if attempt <= 10
    return attempt * 3 if attempt <= 20
    return attempt * 4
  end

  def _fatal(d, e)
    Webhookdb::DeveloperAlert.new(
      subsystem: "Webhook Subscriptions",
      emoji: ":hook:",
      fallback: "Error delivering WebhookSubscription::Delivery[id: #{d.id}, subscription_id: #{self.id}]: #{e}",
      fields: [
        {title: "Org", value: self.fetch_organization.display_string, short: true},
        {title: "Creator", value: self.created_by&.email, short: true},
        {title: "Delivery", value: "#{d.id}, Subscription: #{self.id}, Attempts: #{d.attempt_count}"},
        {title: "URL", value: self.deliver_to_url, short: false},
        {title: "Exception", value: e.inspect, short: false},
      ],
    ).emit
  end

  def associated_type
    return "organization" unless self.organization_id.nil?
    return "service_integration" unless self.service_integration_id.nil?
    return ""
  end

  def associated_id
    return self.organization.key unless self.organization_id.nil?
    return self.service_integration.opaque_id unless self.service_integration_id.nil?
    return ""
  end

  #
  # :Sequel Hooks:
  #

  def before_create
    self[:opaque_id] ||= Webhookdb::Id.new_opaque_id("wsb")
  end
end

# Table: webhook_subscriptions
# ----------------------------------------------------------------------------------------------------------------------------------------------------------------
# Columns:
#  id                     | integer                  | PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY
#  deliver_to_url         | text                     | NOT NULL
#  webhook_secret         | text                     | NOT NULL
#  opaque_id              | text                     | NOT NULL
#  service_integration_id | integer                  |
#  organization_id        | integer                  |
#  created_at             | timestamp with time zone | NOT NULL DEFAULT now()
#  updated_at             | timestamp with time zone |
#  created_by_id          | integer                  |
#  deactivated_at         | timestamp with time zone |
#  text_search            | tsvector                 |
# Indexes:
#  webhook_subscriptions_pkey          | PRIMARY KEY btree (id)
#  webhook_subscriptions_opaque_id_key | UNIQUE btree (opaque_id)
# Check constraints:
#  service_integration_or_org | (service_integration_id IS NULL AND organization_id IS NOT NULL OR service_integration_id IS NOT NULL AND organization_id IS NULL)
# Foreign key constraints:
#  webhook_subscriptions_created_by_id_fkey          | (created_by_id) REFERENCES customers(id)
#  webhook_subscriptions_organization_id_fkey        | (organization_id) REFERENCES organizations(id)
#  webhook_subscriptions_service_integration_id_fkey | (service_integration_id) REFERENCES service_integrations(id)
# Referenced By:
#  webhook_subscription_deliveries | webhook_subscription_deliveries_webhook_subscription_id_fkey | (webhook_subscription_id) REFERENCES webhook_subscriptions(id)
# ----------------------------------------------------------------------------------------------------------------------------------------------------------------
