# frozen_string_literal: true

require "webhookdb/email_octopus"

class Webhookdb::Replicator::EmailOctopusCampaignV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "email_octopus_campaign_v1",
      ctor: ->(sint) { Webhookdb::Replicator::EmailOctopusCampaignV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "Email Octopus Campaign",
      dependency_descriptor: Webhookdb::Replicator::EmailOctopusListV1.descriptor,
      supports_backfill: true,
    )
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:email_octopus_id, TEXT, data_key: "id")
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:name, TEXT),
      Webhookdb::Replicator::Column.new(:created_at, TIMESTAMP, index: true, converter: :time),
      Webhookdb::Replicator::Column.new(:sent_at, TIMESTAMP, index: true, converter: :time),
      Webhookdb::Replicator::Column.new(:status, TEXT),
      Webhookdb::Replicator::Column.new(:from_name, TEXT, data_key: ["from", "name"]),
      Webhookdb::Replicator::Column.new(:from_email_address, TEXT, data_key: ["from", "email_address"]),
      Webhookdb::Replicator::Column.new(:subject, TEXT),
      Webhookdb::Replicator::Column.new(:row_updated_at, TIMESTAMP, defaulter: :now, optional: true),
    ]
  end

  def _resource_and_event(request)
    return request.body, nil
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:data] !~ Sequel[:excluded][:data]
  end

  def _timestamp_column_name
    return :row_updated_at
  end

  def _webhook_response(_request)
    return Webhookdb::WebhookResponse.ok
  end

  def on_dependency_webhook_upsert(_replicator, _payload, *)
    return
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

  def _fetch_backfill_page(pagination_token, **)
    api_key = self.service_integration.depends_on.replicator.backfill_key!
    limit = Webhookdb::EmailOctopus.page_size
    base_url = "https://emailoctopus.com"
    endpoint_path = pagination_token || "/api/1.6/campaigns?api_key=#{api_key}&limit=#{limit}"
    response = Webhookdb::Http.get(
      base_url + endpoint_path,
      logger: self.logger,
      timeout: Webhookdb::EmailOctopus.http_timeout,
    )
    data = response.parsed_response
    next_page_link = data.dig("paging", "next")
    return data["data"], next_page_link
  end
end
