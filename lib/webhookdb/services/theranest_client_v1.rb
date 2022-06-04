# frozen_string_literal: true

require "webhookdb/theranest"
require "webhookdb/services/theranest_v1_mixin"

class Webhookdb::Services::TheranestClientV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::TheranestV1Mixin

  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "theranest_client_v1",
      ctor: self,
      feature_roles: ["theranest"],
      resource_name_singular: "Theranest Client",
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
    return Webhookdb::Services::Column.new(:theranest_id, TEXT)
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:archived_in_theranest, BOOLEAN),
      Webhookdb::Services::Column.new(:birth_date, DATE),
      Webhookdb::Services::Column.new(:created_in_theranest_at, DATE),
      Webhookdb::Services::Column.new(:email, TEXT),
      Webhookdb::Services::Column.new(:external_client_id, TEXT),
      Webhookdb::Services::Column.new(:external_location_id, INTEGER),
      Webhookdb::Services::Column.new(:full_name, TEXT),
      Webhookdb::Services::Column.new(:preferred_name, TEXT),
    ]
  end

  def _update_where_expr
    return Sequel[self.table_sym][:data] !~ Sequel[:excluded][:data]
  end

  def _timestamp_column_name
    return :created_in_theranest_at
  end

  def _prepare_for_insert(obj, **_kwargs)
    # TODO: Add rest of columns, even the ones whose info can't be retrieved from the API,
    # for the sake of fully matching the existing DB schema?
    return {
      theranest_id: obj.fetch("Id"),
      archived_in_theranest: obj.fetch("IsArchived"),
      birth_date: parse_ymd_date(obj.fetch("DateOfBirthYMD")),
      created_in_theranest_at: parse_ymd_date(obj.fetch("RegistrationDateTimeYMD")),
      email: obj.fetch("Email"),
      external_client_id: obj.fetch("ClientIdNumber"),
      external_location_id: obj.fetch("LocationId").to_i,
      full_name: obj.fetch("FullName"),
      preferred_name: obj.fetch("PreferredName"),
    }
  end

  def _verify_backfill_err_msg
    return "Looks like your auth cookie has expired."
  end

  def _fetch_backfill_page(pagination_token, **_kwargs)
    auth = self.find_auth_integration.service_instance
    count = Webhookdb::Theranest.page_size
    offset = pagination_token.present? ? pagination_token : 0
    url = self.find_auth_integration.api_url + "/api/clients/listing"

    response = Webhookdb::Http.get(
      url,
      query: {
        take: count,
        skip: offset,
        fullNameSort: "asc",
      },
      headers: auth.get_auth_headers,
      logger: self.logger,
    )
    data = response.parsed_response["Data"]
    return data, nil if data.size < count
    return data, offset + count
  end

  def _check_backfill_credentials!
    # we shouldn't check backfill credentials here
    return
  end
end
