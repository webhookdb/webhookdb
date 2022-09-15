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

  # Appointments are a pretty weird resource.
  # We 'paginate' by looking at dates.
  # Incremental backfills paginate from this month forward to the configured 'look ahead' date;
  # full backfills paginate from a 'look back' date forward to the configured 'look ahead' date.
  def _fetch_backfill_page(pagination_token, last_backfilled:)
    now = Time.now
    if pagination_token.nil?
      # We are starting our backfill. If it's complete, go far back.
      # If it's incremental, start last month, not this month, so we don't miss anything
      # at month boundaries.
      complete_backfill = last_backfilled.nil?
      months_back = complete_backfill ? Webhookdb::Theranest.appointment_look_back_months : 1
      pagination_token = (now - months_back.months).utc.beginning_of_month
    end
    start_of_query_month = pagination_token
    end_of_query_month = start_of_query_month + 1.month # end is exclusive
    url = self.find_auth_integration.api_url + "/api/appointments/getAppointments"
    headers = theranest_auth_headers.merge({"accept-encoding" => "none"})
    response = Webhookdb::Http.post(
      url,
      {"From" => start_of_query_month, "To" => end_of_query_month},
      headers:,
      logger: self.logger,
    )
    data = response.parsed_response
    forward_cutoff = now + Webhookdb::Theranest.appointment_look_forward_months.months
    # If the next month we'd query for is after our cutoff month, stop querying.
    next_token = end_of_query_month > forward_cutoff ? nil : end_of_query_month
    return data, next_token
  end
end
