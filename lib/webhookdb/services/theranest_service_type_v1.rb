# frozen_string_literal: true

require "webhookdb/theranest"
require "webhookdb/services/theranest_v1_mixin"

class Webhookdb::Services::TheranestServiceTypeV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::TheranestV1Mixin

  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "theranest_service_type_v1",
      ctor: self,
      feature_roles: ["theranest"],
      resource_name_singular: "Theranest Service Type",
      dependency_descriptor: Webhookdb::Services::TheranestAuthV1.descriptor,
    )
  end

  def calculate_create_state_machine
    # can inherit the `.ASPXAUTH` piece of the cookie and the API url from the auth dependency
    if (step = self.calculate_dependency_state_machine_step(dependency_help: ""))
      return step
    end
    step = Webhookdb::Services::StateMachineStep.new
    step.output = %(Great! If you have fully set up your Theranest Auth integration, you are all set.

#{self._query_help_output(prefix: "Once data is available, you can query #{self.resource_name_plural}.")})
    return step.completed
  end

  # @return [Webhookdb::Services::StateMachineStep]
  def calculate_backfill_state_machine
    step = Webhookdb::Services::StateMachineStep.new
    step.output = %(We will start backfilling #{self.resource_name_singular} information into your WebhookDB database.

#{self._query_help_output(prefix: "Once data is available, you can query #{self.resource_name_plural}.")})
    return step.completed
  end

  def _webhook_response(_request)
    # Webhook Authentication isn't supported
    return Webhookdb::WebhookResponse.ok
  end

  def on_dependency_webhook_upsert(_service_instance, _payload, *)
    return
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:external_id, TEXT)
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:archived, TEXT),
      # Webhookdb::Services::Column.new(:code, TEXT), TODO: how to retrieve this from the list endpoint
      Webhookdb::Services::Column.new(:formatted_name, TEXT),
      # Webhookdb::Services::Column.new(:name, TEXT), TODO: how to retrieve this from the list endpoint
      Webhookdb::Services::Column.new(:updated_at, TIMESTAMP),
    ]
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:data] !~ Sequel[:excluded][:data]
  end

  def _timestamp_column_name
    return :updated_at
  end

  def _prepare_for_insert(obj, **_kwargs)
    return {
      external_id: obj.fetch("key"),
      archived: obj.fetch("isArchived"),
      formatted_name: obj.fetch("label"),
      updated_at: DateTime.now,
    }
  end

  def _verify_backfill_err_msg
    return "Looks like your auth cookie has expired."
  end

  def _fetch_backfill_page(_pagination_token, **_kwargs)
    auth = self.find_auth_integration.service_instance
    url = self.find_auth_integration.api_url + "/api/appointments/GetFilterValues"

    response = Webhookdb::Http.get(
      url,
      headers: auth.get_auth_headers,
      logger: self.logger,
    )
    data = response.parsed_response["ServiceTypes"]

    # this array contains a dummy entry, "* No Service Type *", for which there is no "key" (i.e. external_id).
    # We filter it out here.
    data = data.filter { |entry| entry.fetch("key").present? }

    return data, nil
  end

  def _check_backfill_credentials!
    # we shouldn't check backfill credentials here
    return
  end
end
