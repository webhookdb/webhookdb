# frozen_string_literal: true

require "webhookdb/email_octopus"

class Webhookdb::Replicator::EmailOctopusCampaignEventV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "email_octopus_campaign_event_v1",
      ctor: ->(sint) { Webhookdb::Replicator::EmailOctopusCampaignEventV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "Email Octopus Campaign Event",
      dependency_descriptor: Webhookdb::Replicator::EmailOctopusCampaignV1.descriptor,
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
      md5.update(resource.fetch("campaign_id"))
      md5.hexdigest
    end,
  )

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:unique_id, UUID, optional: true, defaulter: BUILD_EVENT_MD5)
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:email_octopus_contact_id, TEXT, data_key: ["contact", "id"]),
      Webhookdb::Replicator::Column.new(:contact_email_address, TEXT, data_key: ["contact", "email_address"]),
      Webhookdb::Replicator::Column.new(:email_octopus_campaign_id, TEXT, data_key: ["campaign_id"]),
      Webhookdb::Replicator::Column.new(:event_type, TEXT),
      Webhookdb::Replicator::Column.new(:occurred_at, TIMESTAMP, index: true, converter: :time),
    ]
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

  def _timestamp_column_name
    return :occurred_at
  end

  def _webhook_response(_request)
    return Webhookdb::WebhookResponse.ok
  end

  def calculate_backfill_state_machine
    if (step = self.calculate_dependency_state_machine_step(dependency_help: ""))
      return step
    end
    step = Webhookdb::Replicator::StateMachineStep.new
    # We're using the API Key from the dependency, we don't need to ask for it here
    step.output = %(Great! We are going to start replicating your #{self.resource_name_plural}.
#{self._query_help_output}
    )
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
    "sent",
    "unsubscribed",
  ].freeze

  def _backfillers
    campaign_sint = self.service_integration.depends_on
    unless campaign_sint.backfill_key.present?
      raise Webhookdb::Replicator::CredentialsMissing,
            "This integration requires that the Email Octopus Campaign integration has a valid API Key"
    end

    campaign_svc = campaign_sint.replicator
    backfillers = campaign_svc.admin_dataset(timeout: :fast) do |campaign_ds|
      campaign_ds.select(:email_octopus_id).flat_map do |campaign|
        CAMPAIGN_EVENT_TYPES.map do |event_type|
          CampaignEventBackfiller.new(
            campaign_event_svc: self,
            campaign_id: campaign[:email_octopus_id],
            api_key: campaign_sint.backfill_key,
            event_type:,
          )
        end
      end
    end
    return backfillers
  end

  class CampaignEventBackfiller < Webhookdb::Backfiller
    include Webhookdb::Backfiller::Bulk

    def initialize(campaign_event_svc:, campaign_id:, api_key:, event_type:)
      @campaign_event_svc = campaign_event_svc
      @campaign_id = campaign_id
      @api_key = api_key
      @event_type = event_type
      super()
    end

    def upserting_replicator = @campaign_event_svc
    def upsert_page_size = 500

    def prepare_body(body)
      body["campaign_id"] = @campaign_id
      body["event_type"] = @event_type
    end

    def fetch_backfill_page(pagination_token, **_kwargs)
      limit = Webhookdb::EmailOctopus.page_size
      base_url = "https://emailoctopus.com"
      # rubocop:disable Layout/LineLength
      endpoint_path = pagination_token || "/api/1.6/campaigns/#{@campaign_id}/reports/#{@event_type}?api_key=#{@api_key}&limit=#{limit}"
      # rubocop:enable Layout/LineLength
      response = Webhookdb::Http.get(
        base_url + endpoint_path,
        logger: @campaign_event_svc.logger,
      )
      data = response.parsed_response
      # if no data is returned from endpoint, the "paging" and "data" values are both empty arrays
      next_page_link = data.fetch("paging").empty? ? nil : data.dig("paging", "next")
      return data["data"], next_page_link
    end
  end
end
