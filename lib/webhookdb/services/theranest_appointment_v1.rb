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

  def _remote_key_column
    return Webhookdb::Services::Column.new(:external_id, TEXT, data_key: "id")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:end_time, TIMESTAMP, data_key: "end_date"),
      Webhookdb::Services::Column.new(:start_time, TIMESTAMP, data_key: "start_date"),
      Webhookdb::Services::Column.new(:status, TEXT, data_key: ["status", "Status"]),
      Webhookdb::Services::Column.new(
        :updated_at,
        TIMESTAMP,
        optional: true,
        defaulter: :now,
        index: true,
      ),
    ]
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:data] !~ Sequel[:excluded][:data]
  end

  def _timestamp_column_name
    return :updated_at
  end

  def _verify_backfill_err_msg
    return "Looks like your auth cookie has expired."
  end

  def _fetch_backfill_page(_pagination_token, **_kwargs)
    url = self.find_auth_integration.api_url + "/api/appointments/getAppointments"
    headers = theranest_auth_headers.merge({"accept-encoding" => "none"})

    response = Webhookdb::Http.post(
      url,
      {},
      headers:,
      logger: self.logger,
    )
    data = response.parsed_response
    return data, nil
  end
end
