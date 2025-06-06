# frozen_string_literal: true

require "webhookdb/email_octopus"

class Webhookdb::Replicator::EmailOctopusListV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "email_octopus_list_v1",
      ctor: ->(sint) { Webhookdb::Replicator::EmailOctopusListV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "Email Octopus List",
      supports_backfill: true,
      api_docs_url: "https://emailoctopus.com/api-documentation",
    )
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:email_octopus_id, TEXT, data_key: "id")
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:name, TEXT),
      Webhookdb::Replicator::Column.new(:created_at, TIMESTAMP, index: true, converter: :time),
      Webhookdb::Replicator::Column.new(:pending, INTEGER, data_key: ["counts", "pending"]),
      Webhookdb::Replicator::Column.new(:subscribed, INTEGER, data_key: ["counts", "subscribed"]),
      Webhookdb::Replicator::Column.new(:unsubscribed, INTEGER, data_key: ["counts", "unsubscribed"]),
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

  def calculate_backfill_state_machine
    step = Webhookdb::Replicator::StateMachineStep.new
    unless self.service_integration.backfill_key.present?
      step.output = %(In order to replicate #{self.resource_name_plural} into WebhookDB, we need an API Key.
From your Email Octopus dashboard, go to Account Settings -> Integrations & API.
Then, click through to the API menu, under the "Developer tools" header and create a key.

Copy the key.
      )
      return step.secret_prompt("API Key").backfill_key(self.service_integration)
    end

    unless self.verify_backfill_credentials.verified?
      self.service_integration.replicator.clear_backfill_information
      return self.calculate_backfill_state_machine.
          with_output("It looks like that API key is invalid. Please reenter your API Key:")
    end

    step.output = %(Great! We are going to start replicating your #{self.resource_name_plural}.
#{self._query_help_output}
    )
    return step.completed
  end

  def _fetch_backfill_page(pagination_token, **)
    api_key = self.backfill_key!
    limit = Webhookdb::EmailOctopus.page_size
    base_url = "https://emailoctopus.com"
    endpoint_path = pagination_token || "/api/1.6/lists?api_key=#{api_key}&limit=#{limit}"
    response = Webhookdb::Http.get(
      base_url + endpoint_path,
      logger: self.logger,
      timeout: Webhookdb::EmailOctopus.http_timeout,
    )
    data = response.parsed_response
    next_page_link = data.dig("paging", "next")
    return data["data"], next_page_link
  end

  def backfill_key!
    bk = self.service_integration.backfill_key

    return bk if bk.present?
    raise Webhookdb::Replicator::CredentialsMissing,
          "This integration requires that the #{self.descriptor.name} integration has a valid API Key"
  end
end
