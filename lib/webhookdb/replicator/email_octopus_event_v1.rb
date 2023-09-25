# frozen_string_literal: true

require "webhookdb/email_octopus"

class Webhookdb::Replicator::EmailOctopusEventV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "email_octopus_event_v1",
      ctor: ->(sint) { Webhookdb::Replicator::EmailOctopusEventV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "Email Octopus Event",
      dependency_descriptor: Webhookdb::Replicator::EmailOctopusListV1.descriptor,
      supports_webhooks: true,
      supports_backfill: true,
    )
  end
  BUILD_EVENT_MD5 = Webhookdb::Replicator::Column::IsomorphicProc.new(
    ruby: lambda do |resource:, **|
      # MD5 includes occurred_at, event_type, email_octopus_contact_id, and email_octopus_campaign_id.
      md5 = Digest::MD5.new
      md5.update(resource.fetch("occurred_at"))
      md5.update(resource.fetch("event_type"))
      md5.update(resource.dig("contact", "id"))
      md5.update(resource.fetch("campaign_id", "missing"))
      md5.hexdigest
    end,
  )

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:unique_id, UUID_COL, optional: true, defaulter: BUILD_EVENT_MD5)
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:email_octopus_contact_id, TEXT, data_key: ["contact", "id"]),
      Webhookdb::Replicator::Column.new(:contact_email_address, TEXT, data_key: ["contact", "email_address"]),
      Webhookdb::Replicator::Column.new(:email_octopus_campaign_id, TEXT, data_key: ["campaign_id"], optional: true),
      Webhookdb::Replicator::Column.new(:event_type, TEXT),
      Webhookdb::Replicator::Column.new(:occurred_at, TIMESTAMP, index: true, converter: :time),
    ]
  end

  def _timestamp_column_name
    return :occurred_at
  end

  def _upsert_webhook(request, upsert: true)
    return super unless request.body.is_a?(Array)

    # If the body is an array, it means we are upserting data from webhooks and have to transform the data
    # in order to be able to upsert.
    new_bodies = request.body.map do |wh|
      new_body = {
        "contact" => {
          "id" => wh.fetch("contact_id"),
          "email_address" => wh.fetch("contact_email_address"),
        },
        "occurred_at" => wh.fetch("occurred_at"),
        "event_type" => wh.fetch("type"),
      }

      # "campaign_id" isn't always populated in the webhoooks, it is only there on event types that are tied
      # to a specific "campaign", (that's Email Octopus's word for an email message), like "bounced" or "opened"
      if (campaign_id = wh["campaign_id"])
        new_body["campaign_id"] = campaign_id
      end
      new_body
    end

    new_bodies.each do |b|
      new_request = request.dup
      new_request.body = b
      super(new_request, upsert:)
    end

    list_svc = self.service_integration.depends_on.replicator
    contact_sint = list_svc.find_dependent("email_octopus_contact_v1")
    return unless contact_sint
    contact_svc = contact_sint.replicator
    # For events that pertain to a contact being created or updated in some way, we also upsert them using
    # the contact integration so that the new information can be recorded in the contact table
    contact_event_types = ["contact.created", "contact.updated", "contact.deleted"]
    contact_events = request.body.filter { |nb| contact_event_types.include?(nb.fetch("type")) }
    return if contact_events.empty?
    contact_request = request.dup
    contact_request.body = contact_events
    contact_svc._upsert_webhook(contact_request, upsert:)
  end

  def _resource_and_event(request)
    return request.body, nil
  end

  def _update_where_expr
    # 'occurred_at' is the timestamp, but it's used in the unique id,
    # so there's no way to use it as part of the conditional upsert.
    # So events are effectively immutable, and we know we shouldn't bother overwriting what's already in the DB.
    return Sequel[false]
  end

  def _webhook_response(request)
    signature_header = request.env["HTTP_EMAILOCTOPUS_SIGNATURE"]
    return Webhookdb::WebhookResponse.error("missing signature") if signature_header.nil?

    request.body.rewind
    data = request.body.read
    verified = Webhookdb::EmailOctopus.verify_webhook(data, signature_header, self.service_integration.webhook_secret)
    return Webhookdb::WebhookResponse.ok if verified
    return Webhookdb::WebhookResponse.error("invalid signature")
  end

  def calculate_webhook_state_machine
    if (step = self.calculate_dependency_state_machine_step(dependency_help: ""))
      return step
    end
    step = Webhookdb::Replicator::StateMachineStep.new
    unless self.service_integration.webhook_secret.present?
      step.output = %(You are about to start replicating #{self.resource_name_plural} into WebhookDB.
We've made an endpoint available for #{self.resource_name_singular} webhooks:

#{self._webhook_endpoint}

- From your Email Octopus dashboard, go to Account Settings -> Integrations & API.
- Then click the 'Manage' button next to 'Webhooks'.
- Then under the "Endpoints" header, click "Add endpoint"
- In the "URL" field you can enter the URL above.
- Then check boxes for all events, because we want this webhook to listen for everything.
  This includes:
  - "Contact events to send" -> "Created", "Updated", and "Deleted"
  - "Email events to send" -> Deleted" "Clicked", "Opened", "Bounced",
    "Complained", and "Unsubscribed"
  - You can keep the checkboxes under "Exclude contact events that occur" unchecked.

- Save the endpoint.

You'll be dropped back on the Webhooks page.
Click 'View Secret' next to the endpoint you added, and Copy it.
We'll use it for webhook verification.)
      return step.secret_prompt("webhook secret").webhook_secret(self.service_integration)
    end

    step.output = %(Great! WebhookDB is now listening for #{self.resource_name_singular} webhooks.
#{self._query_help_output}
In order to backfill existing #{self.resource_name_plural}, run this from a shell:

  #{self._backfill_command})
    return step.completed
  end

  def calculate_backfill_state_machine
    if (step = self.calculate_dependency_state_machine_step(dependency_help: ""))
      return step
    end
    step = Webhookdb::Replicator::StateMachineStep.new
    # We're using the API Key from the dependency, we don't need to ask for it here
    step.output = %(Great! We are going to start replicating your #{self.resource_name_plural}.
#{self._query_help_output})
    return step.completed
  end

  def on_dependency_webhook_upsert(_replicator, _payload, *)
    return
  end

  CAMPAIGN_EVENT_TYPES = [
    "bounced",
    "clicked",
    "complained",
    "opened",
    "unsubscribed",
  ].freeze

  def _backfillers
    list_sint = self.service_integration.depends_on
    api_key = list_sint.replicator.backfill_key!
    campaign_sint = list_sint.replicator.find_dependent!("email_octopus_campaign_v1")
    campaign_svc = campaign_sint.replicator
    backfillers = campaign_svc.admin_dataset(timeout: :fast) do |campaign_ds|
      campaign_ds.select(:email_octopus_id).flat_map do |campaign|
        CAMPAIGN_EVENT_TYPES.map do |event_type|
          EventBackfiller.new(
            event_svc: self,
            campaign_id: campaign[:email_octopus_id],
            api_key:,
            event_type:,
          )
        end
      end
    end
    return backfillers
  end

  # Because "Event" is an abstraction we've created and does not actually exist in the Email Octopus API,
  # it might seem strange that we are able to "backfill" the resources at all. However, the API has a number of
  # endpoints that they call "campaign reports," which return lists of contacts that have engaged with a campaign
  # in the specified way (e.g. bounced, opened, etc.) In this way, we can retrieve timestamped records of "events" that
  # have already occurred. The only available campaign report endpoint that we don't hit is "sent", which notes the time
  # at which each campaign was sent to each contact. This information doesn't come in through webhooks at all and the
  # timestamps closely match the "sent_at" field in the campaign row, so we have opted not to track it through backfill.
  class EventBackfiller < Webhookdb::Backfiller
    include Webhookdb::Backfiller::Bulk

    def initialize(event_svc:, campaign_id:, api_key:, event_type:)
      @event_svc = event_svc
      @campaign_id = campaign_id
      @api_key = api_key
      @event_type = event_type
      super()
    end

    def upserting_replicator = @event_svc
    def upsert_page_size = 500

    def prepare_body(body)
      body["campaign_id"] = @campaign_id
      body["event_type"] = "contact.#{@event_type}"
    end

    def fetch_backfill_page(pagination_token, **_kwargs)
      limit = Webhookdb::EmailOctopus.page_size
      base_url = "https://emailoctopus.com"
      # rubocop:disable Layout/LineLength
      endpoint_path = pagination_token || "/api/1.6/campaigns/#{@campaign_id}/reports/#{@event_type}?api_key=#{@api_key}&limit=#{limit}"
      # rubocop:enable Layout/LineLength
      response = Webhookdb::Http.get(
        base_url + endpoint_path,
        logger: @event_svc.logger,
        timeout: Webhookdb::EmailOctopus.http_timeout,
      )
      data = response.parsed_response
      # if no data is returned from endpoint, the "paging" and "data" values are both empty arrays
      next_page_link = data.fetch("paging").empty? ? nil : data.dig("paging", "next")
      return data["data"], next_page_link
    end
  end
end
