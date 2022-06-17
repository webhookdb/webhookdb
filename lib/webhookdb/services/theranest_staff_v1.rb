# frozen_string_literal: true

require "webhookdb/theranest"
require "webhookdb/services/theranest_v1_mixin"

class Webhookdb::Services::TheranestStaffV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::TheranestV1Mixin

  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "theranest_staff_v1",
      ctor: self,
      feature_roles: ["theranest"],
      resource_name_singular: "Theranest Staff",
      resource_name_plural: "Theranest Staff",
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
      Webhookdb::Services::Column.new(:active_in_theranest, BOOLEAN),
      Webhookdb::Services::Column.new(:full_name, TEXT),
      Webhookdb::Services::Column.new(:updated_at, TIMESTAMP),
    ]
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:data] !~ Sequel[:excluded][:data]
  end

  def _timestamp_column_name
    return :updated_at
  end

  def _prepare_for_insert(body, **_kwargs)
    return {
      external_id: body.fetch("Id"),
      active_in_theranest: body.fetch("IsActive"),
      full_name: body.fetch("FullName"),
      updated_at: DateTime.now,
    }
  end

  def _verify_backfill_err_msg
    return "Looks like your auth cookie has expired."
  end

  def _fetch_backfill_page(pagination_token, **_kwargs)
    auth = self.find_auth_integration.service_instance

    # need to first backfill active staff, then backfill inactive staff
    backfilling_active = pagination_token.nil?
    pagination_token ||= "/api/staff/getAll/active"
    url = self.find_auth_integration.api_url + pagination_token

    response = Webhookdb::Http.get(
      url,
      headers: auth.get_auth_headers,
      logger: self.logger,
    )
    data = response.parsed_response["Members"]
    # we enrich each of these staff dicts with "IsActive" info
    data.map do |entry|
      entry.merge!({"IsActive" => backfilling_active})
    end

    return data, "/api/staff/getAll/inactive" if backfilling_active
    return data, nil
  end

  def _check_backfill_credentials!
    # we shouldn't check backfill credentials here
    return
  end
end
