# frozen_string_literal: true

require "webhookdb/theranest"
require "webhookdb/services/theranest_v1_mixin"

class Webhookdb::Services::TheranestAppointmentV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::TheranestV1Mixin

  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "theranest_appointment_v1",
      ctor: self,
      feature_roles: ["theranest"],
      resource_name_singular: "Theranest Appointment",
      dependency_descriptor: Webhookdb::Services::TheranestAuthV1.descriptor,
    )
  end

  def service_types_join_table_name
    return "#{self.service_integration.table_name}_service_types".to_sym
  end

  def service_types_dataset(&)
    return self.admin_dataset(timeout: :fast) do |ds|
      yield(ds.db[self.qualified_table_sequel_identifier(table: self.service_types_join_table_name)])
    end
  end

  def _enrichment_tables_descriptors
    table = Webhookdb::DBAdapter::Table.new(name: self.service_types_join_table_name)
    apptcol = Webhookdb::DBAdapter::Column.new(name: :theranest_appointment_id, type: TEXT)
    typecol = Webhookdb::DBAdapter::Column.new(name: :theranest_service_type_id, type: TEXT)
    return [
      Webhookdb::DBAdapter::TableDescriptor.new(
        table:,
        columns: [
          Webhookdb::DBAdapter::Column.new(name: :pk, type: BIGINT, pk: true),
          apptcol,
          typecol,
        ],
        indices: [
          Webhookdb::DBAdapter::Index.new(
            name: :appt_type_idx,
            table:,
            targets: [apptcol, typecol],
            unique: true,
          ),
        ],
      ),
    ]
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
      Webhookdb::Services::Column.new(:end_time, TIMESTAMP),
      Webhookdb::Services::Column.new(:start_time, TIMESTAMP),
      Webhookdb::Services::Column.new(:status, TEXT),
      Webhookdb::Services::Column.new(:updated_at, TIMESTAMP),

    ]
  end

  def enrichment_tables
    return [self.service_types_join_table_name.to_s]
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:data] !~ Sequel[:excluded][:data]
  end

  def _timestamp_column_name
    return :updated_at
  end

  def _prepare_for_insert(body, **_kwargs)
    return {
      external_id: body.fetch("id"),
      start_time: body.fetch("start_date"),
      end_time: body.fetch("end_date"),
      status: body.fetch("status").fetch("Status"),
      updated_at: DateTime.now,
    }
  end

  def _fetch_enrichment(body)
    return body.fetch("serviceTypeIds")
  end

  def _after_insert(inserting, enrichment:)
    # TODO: Should we support removing service types from an appointment?
    appt_id = inserting[:external_id]
    type_ids = enrichment
    rows = type_ids.map do |type_id|
      {
        theranest_appointment_id: appt_id,
        theranest_service_type_id: type_id,
      }
    end
    self.service_types_dataset do |ds|
      ds.
        insert_conflict(target: [:theranest_appointment_id, :theranest_service_type_id]).
        multi_insert(rows)
    end
  end

  def _verify_backfill_err_msg
    return "Looks like your auth cookie has expired."
  end

  def _fetch_backfill_page(_pagination_token, **_kwargs)
    auth = self.find_auth_integration.service_instance
    url = self.find_auth_integration.api_url + "/api/appointments/getAppointments"
    headers = auth.get_auth_headers.merge({"accept-encoding" => "none"})

    response = Webhookdb::Http.post(
      url,
      {},
      headers:,
      logger: self.logger,
    )
    data = response.parsed_response
    return data, nil
  end

  def _check_backfill_credentials!
    # we shouldn't check backfill credentials here
    return
  end
end
