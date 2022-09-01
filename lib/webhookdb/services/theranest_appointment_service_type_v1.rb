# frozen_string_literal: true

require "webhookdb/theranest"
require "webhookdb/services/theranest_v1_mixin"

class Webhookdb::Services::TheranestAppointmentServiceTypeV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::TheranestV1Mixin

  # @return [Webhookdb::Services::Descriptor]
  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "theranest_appointment_service_type_v1",
      ctor: ->(sint) { Webhookdb::Services::TheranestAppointmentServiceTypeV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "Theranest Appointment Service Types",
      resource_name_plural: "Theranest Appointment Service Types",
      dependency_descriptor: Webhookdb::Services::TheranestAppointmentV1.descriptor,
    )
  end

  CONV_REMOTE_KEY = Webhookdb::Services::Column::IsomorphicProc.new(
    ruby: ->(_, item) { "#{item.fetch('appointment_id')}-#{item.fetch('service_type_id')}" },
    # Because this is a non-nullable key, we never need this in SQL
    sql: ->(_) { Sequel.lit("'do not use'") },
  )

  def _remote_key_column
    return Webhookdb::Services::Column.new(
      :compound_identity,
      TEXT,
      data_key: "<compound key, see converter>",
      index: true,
      converter: CONV_REMOTE_KEY,
      optional: true, # This is done via the converter, data_key never exists
    )
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:appointment_id, TEXT),
      Webhookdb::Services::Column.new(:row_updated_at, TIMESTAMP, defaulter: :now, optional: true),
      Webhookdb::Services::Column.new(:service_type_id, TEXT),
    ]
  end

  def _timestamp_column_name
    return :row_updated_at
  end

  def _resource_and_event(body)
    return body, nil
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:data] !~ Sequel[:excluded][:data]
  end

  def _backfillers
    appointment_svc = self.service_integration.depends_on.service_instance
    backfillers = appointment_svc.admin_dataset(timeout: :fast) do |appointment_ds|
      appointment_ds.select(:external_id, :data).map do |appointment|
        AppointmentServiceTypeBackfiller.new(
          appointment_service_type_svc: self,
          appointment_id: appointment[:external_id],
          appointment_data: appointment[:data],
        )
      end
    end

    return backfillers
  end

  class AppointmentServiceTypeBackfiller < Webhookdb::Backfiller
    def initialize(appointment_service_type_svc:, appointment_id:, appointment_data:)
      @appointment_service_type_svc = appointment_service_type_svc
      @appointment_id = appointment_id
      @appointment_data = appointment_data
      super()
    end

    def handle_item(item)
      @appointment_service_type_svc.upsert_webhook_body(item)
    end

    def fetch_backfill_page(_pagination_token, **_kwargs)
      service_type_ids = @appointment_data.fetch("serviceTypeIds")
      appointment_service_types = service_type_ids.map do |id|
        {"appointment_id" => @appointment_id, "service_type_id" => id}
      end
      return appointment_service_types, nil
    end
  end
end
