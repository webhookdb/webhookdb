# frozen_string_literal: true

require "webhookdb/replicator/oauth_refresh_access_token_mixin"
require "webhookdb/replicator/microsoft_calendar_v1_mixin"

class Webhookdb::Replicator::MicrosoftCalendarUserV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::OAuthRefreshAccessTokenMixin
  include Webhookdb::Replicator::MicrosoftCalendarV1Mixin

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "microsoft_calendar_user_v1",
      ctor: Webhookdb::Replicator::MicrosoftCalendarUserV1,
      feature_roles: ["microsoft", "beta"],
      resource_name_singular: "Outlook Calendar User",
      supports_webhooks: true,
    )
  end

  def _remote_key_column
    # Provided by the client/caller, usually their user id.
    # The calendar user is an abstraction around handling auth information and thus has no microsoft id.
    return Webhookdb::Replicator::Column.new(:microsoft_user_id, TEXT)
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:row_created_at, TIMESTAMP, index: true, optional: true, defaulter: :now),
      Webhookdb::Replicator::Column.new(:row_updated_at, TIMESTAMP, index: true, optional: true, defaulter: :now),
      # Provided by the client for each of their users.
      Webhookdb::Replicator::Column.new(:encrypted_refresh_token, TEXT, skip_nil: true),
      Webhookdb::Replicator::Column.new(:events_subscription_id, TEXT, skip_nil: true, optional: true, index: true),
      Webhookdb::Replicator::Column.new(:events_subscription_expiration, TIMESTAMP, index: true, skip_nil: true,
                                                                                    optional: true,),
    ]
  end

  def _timestamp_column_name
    return :row_updated_at
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:row_updated_at] < Sequel[:excluded][:row_updated_at]
  end

  def _resource_to_data(resource, _event, _request)
    data = resource.dup
    data.delete("type")
    data.delete("encrypted_refresh_token")
    data.delete("microsoft_user_id")
    return data
  end

  def calculate_webhook_state_machine
    step = Webhookdb::Replicator::StateMachineStep.new
    if self.service_integration.webhook_secret.blank?
      self.service_integration.data_encryption_secret ||= Webhookdb::Crypto.encryption_key.base64
      self.service_integration.save_changes
      step.output = %(You are about to add support for replicating Outlook Calendar Users into WebhookDB,
which is required for replicating the calendars and events themselves.

We have detailed instructions on this process
at https://webhookdb.com/docs/outlook-calendar.

The first step is to generate a secret you will use for signing
API requests you send to WebhookDB. You can use '#{Webhookdb::Id.rand_enc(16)}'
or generate your own value.
Copy and paste or enter a new value, and press enter.)
      return step.secret_prompt("secret").webhook_secret(self.service_integration)
    end
    if self.service_integration.backfill_key.blank?
      step.output = %(In order to generate OAuth access tokens,
we will need the Client ID and Client Secret for your registered app, plus the associated tenant id.
Again, see detailed instructions at https://webhookdb.com/docs/outlook-calendar.)
      return step.secret_prompt("Client ID").backfill_key(self.service_integration)
    end
    if self.service_integration.backfill_secret.blank?
      return step.secret_prompt("Client Secret").backfill_secret(self.service_integration)
    end
    step.output = %(All set! Here is the endpoint to send requests to
from your backend. Refer to https://webhookdb.com/docs/outlook-calendar
for details on the format of the request:

#{self.webhook_endpoint}

The secret to use for signing is:

#{self.service_integration.webhook_secret}

    #{self._query_help_output})
    return step.completed
  end

  def upsert_webhook(request)
    # if microsoft is sending us a change notification here:
    notification_bodies = request.body.fetch("value", nil)
    if notification_bodies.present?
      # Microsoft will sometimes send us multiple change notifications at once...even when there is a single
      # notification it is sent as an array. We use the subscription ID to match which user rows we need to sync
      # events for.
      notification_bodies.each do |notification|
        events_subscription_id = notification.fetch("subscriptionId")
        user_row = self.admin_dataset { |ds| ds.where(events_subscription_id:).first }
        raise Webhookdb::InvalidPostcondition, "there is no calendar user with that subscription id" if user_row.nil?
        sync_calendar_user_calendars_and_events(self, user_row)
      end
      return
    end

    client_request_type = request.body["type"]
    return unless client_request_type
    # Avoid mutating the request, since it leads to weird issues since we pass
    # the body around to dependents and whatnot.
    new_body = request.body.dup
    microsoft_user_id = new_body.fetch("microsoft_user_id")
    refresh_token = new_body.delete("refresh_token")
    unless self.service_integration.data_encryption_secret.present?
      raise Webhookdb::InvalidPrecondition,
            "no data encryption secret on the integration"
    end
    if refresh_token
      new_body["encrypted_refresh_token"] = Webhookdb::Crypto.encrypt_value(
        Webhookdb::Crypto::Boxed.from_b64(self.service_integration.data_encryption_secret),
        Webhookdb::Crypto::Boxed.from_raw(refresh_token),
      ).base64
    end
    request = request.change(body: new_body)
    case client_request_type
      when "LINK", "LINKED"
        user_row = super(request)
      when "REFRESH", "REFRESHED"
        # When a user updates their auth in a client's system, they send us the new information
        # and we delete the old token.
        user_row = super(request)
        self.delete_oauth_access_token(microsoft_user_id)
      when "RESYNC"
        self.clear_delta_urls_for_user(microsoft_user_id)
        user_row = self.admin_dataset { |ds| ds[microsoft_user_id:] }
      when "UNLINK", "UNLINKED"
        # When a user unlinks their calendar from a client's system, they send us this.
        # Delete all calendar data for the client, including the relevant calendar user rows.
        relevant_integrations = self.service_integration.recursive_dependents.
          filter { |d| CLEANUP_SERVICE_NAMES.include?(d.service_name) }
        self.admin_dataset do |ds|
          ds.db.transaction do
            ds.where(microsoft_user_id:).delete
            relevant_integrations.each do |sint|
              ds.db[sint.replicator.qualified_table_sequel_identifier].where(microsoft_user_id:).delete
            end
          end
        end
        return
      when "__WHDB_UNIT_TEST"
        unless Webhookdb::RACK_ENV == "test"
          raise "someone tried to use the special unit test microsoft calendar event type outside of unit tests"
        end
        return super(request)
      else
        raise "Unknown MicrosoftCalendarUserV1 request type: #{client_request_type}"
    end

    # We trigger full syncs for link, refresh, and resync requests.
    sync_calendar_user_calendars_and_events(self, user_row)
    create_or_update_event_change_subscription(self, user_row)
  end

  CLEANUP_SERVICE_NAMES = ["microsoft_calendar_v1", "microsoft_calendar_event_v1"].freeze
  MAX_SUBSCRIPTION_DURATION = 4300.minutes

  def create_or_update_event_change_subscription(calendar_user_svc, calendar_user_row)
    microsoft_user_id = calendar_user_row.fetch(:microsoft_user_id)
    subscription_id = calendar_user_row.fetch(:events_subscription_id, nil)

    calendar_user_svc.with_access_token(microsoft_user_id) do |access_token|
      calendar_user_svc.admin_dataset do |ds|
        subscription_resp = if subscription_id.nil?
                              self._create_event_change_subscription(access_token)
        else
          self._renew_event_change_subscription(subscription_id, access_token)
        end
        expiration = Time.parse(subscription_resp.fetch("expirationDateTime"))
        ds.where(microsoft_user_id: calendar_user_row.fetch(:microsoft_user_id)).update(
          events_subscription_expiration: expiration,
          events_subscription_id: subscription_id.nil? ? subscription_resp.fetch("id") : subscription_id,
        )
      end
    end
  end

  def _create_event_change_subscription(access_token)
    response = Webhookdb::Http.post(
      "https://graph.microsoft.com/v1.0/subscriptions",
      {
        "changeType" => "created,updated,deleted",
        "resource" => "me/events",
        "notificationUrl" => self.service_integration.replicator.webhook_endpoint,
        "clientState" => self.service_integration.webhook_secret,
        "expirationDateTime" => (Time.now + MAX_SUBSCRIPTION_DURATION).iso8601,
      },
      headers: {"Authorization" => "Bearer #{access_token}"},
      logger: self.logger,
    )
    return response.parsed_response
  end

  def _renew_event_change_subscription(subscription_id, access_token)
    url = "https://graph.microsoft.com/v1.0/subscriptions/#{URI.encode_www_form_component(subscription_id)}"
    response = Webhookdb::Http.post(
      url,
      {"expirationDateTime" => (Time.now + MAX_SUBSCRIPTION_DURATION).iso8601},
      headers: {"Authorization" => "Bearer #{access_token}"},
      logger: self.logger,
      method: :patch,
    )
    return response.parsed_response
  end

  def _webhook_response(request)
    # We need to be able to provide verification when we are setting up our change notification sunscriptions.
    # https://learn.microsoft.com/en-us/graph/webhooks?tabs=http#notification-endpoint-validation
    validation_token = request.params.fetch("validationToken", nil)
    unless validation_token.nil?
      return Webhookdb::WebhookResponse.new(
        status: 200,
        headers: {"Content-Type" => "text/plain;charset=utf-8"},
        body: validation_token,
      )
    end

    # The change notifications from Microsoft will not have the webhook secret in the header, but we can verify
    # that the "clientState" field matches our webhook secret. We should always return a 202 in this case, due to
    # the way Microsoft Graph interprets status codes:
    # https://learn.microsoft.com/en-us/graph/webhooks?tabs=http#processing-the-change-notification

    # The notification bodies come in as an array--let's just check the `clientState` of the first one. As far as I
    # can tell, when multiple notification bodies are sent in it's because they belong to the same subscription, and so
    # it follows that they will all have the same `clientState` value.
    # https://learn.microsoft.com/en-us/graph/webhooks?tabs=http#change-notification-example
    notification_bodies = request.params.fetch("value", nil)
    # verify in the standard way (with secret header) if the request is not from microsoft
    return super(request) if notification_bodies.nil?

    client_state = notification_bodies.first.fetch("clientState", nil)
    return Webhookdb::WebhookResponse.ok if client_state == self.service_integration.webhook_secret
    return Webhookdb::WebhookResponse.error("Client state does not match webhook secret.") unless client_state.nil?
    super(request)
  end

  def bulk_update_expiring_subscriptions
    cutoff = Time.now + 24.hours
    expiring_soon_expr = Sequel[:events_subscription_expiration] < cutoff
    rows = self.admin_dataset do |ds|
      ds.select(:pk, :microsoft_user_id, :events_subscription_id, :encrypted_refresh_token).
        where(expiring_soon_expr).
        all
    end
    rows.each do |row|
      microsoft_user_id = row.fetch(:microsoft_user_id)
      subscription_id = row.fetch(:events_subscription_id)
      subscription_resp = self.with_access_token(microsoft_user_id) do |access_token|
        self._renew_event_change_subscription(subscription_id, access_token)
      end
      expiration = Time.parse(subscription_resp.fetch("expirationDateTime"))
      self.admin_dataset do |ds|
        ds.where(pk: row.fetch(:pk)).update(
          events_subscription_expiration: expiration,
        )
      end
    end
  end

  def clear_delta_urls_for_user(microsoft_user_id)
    # Goes through dependent `microsoft_calendar_v1` integrations and clears delta urls for the given user.
    self.admin_dataset do |ds|
      self.service_integration.dependents.each do |sint|
        ds.db[sint.replicator.qualified_table_sequel_identifier].
          where(microsoft_user_id:).
          update(delta_url: nil)
      end
    end
  end

  def sync_calendar_user_calendars_and_events(calendar_user_svc, calendar_user_row)
    microsoft_user_id = calendar_user_row.fetch(:microsoft_user_id)
    calendar_integrations = self.service_integration.recursive_dependents.filter do |d|
      d.service_name == "microsoft_calendar_v1"
    end

    event_integrations = self.service_integration.recursive_dependents.filter do |d|
      d.service_name == "microsoft_calendar_event_v1"
    end

    calendar_user_svc.with_access_token(microsoft_user_id) do |access_token|
      # First sync the calendars--calendar rows need to be in the database in order for event backfillers
      # to work properly.
      calendar_integrations.each do |cal_int|
        cal_int.replicator.sync_calendar_user_calendars(calendar_user_row, access_token)
      end

      # Then sync the events.
      calendar_rows = calendar_integrations.flat_map do |cal_int|
        cal_int.replicator.admin_dataset do |ds|
          ds.where(microsoft_user_id:).all
        end
      end

      event_integrations.each do |event_int|
        cal_svc = event_int.depends_on.replicator
        calendar_rows.each do |cal_row|
          event_int.replicator.sync_calendar_events(cal_svc, cal_row, access_token)
        end
      end
    end
  end

  # @param microsoft_user_id [String]
  def with_access_token(microsoft_user_id, &)
    cal_user_row = self.admin_dataset do |ds|
      ds.select(:encrypted_refresh_token).where(microsoft_user_id:).first
    end
    if cal_user_row.nil?
      msg = "microsoft user id '#{microsoft_user_id}' has no row in ServiceIntegration[#{self.service_integration.id}]"
      raise Webhookdb::InvalidPrecondition, msg
    end
    self._with_oauth_access_token(microsoft_user_id, -> { self._decrypt_refresh_token(cal_user_row) }, &)
  end

  def _decrypt_refresh_token(row)
    refresh_token = Webhookdb::Crypto.decrypt_value(
      Webhookdb::Crypto::Boxed.from_b64(self.service_integration.data_encryption_secret),
      Webhookdb::Crypto::Boxed.from_b64(row.fetch(:encrypted_refresh_token)),
    ).raw
    return refresh_token
  end

  def upsert_has_deps? = true

  def oauth_cache_key_namespace = "mscalv1"
  def oauth_token_url = "https://login.microsoftonline.com/organizations/oauth2/v2.0/token"
end
