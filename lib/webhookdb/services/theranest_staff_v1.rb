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

  def _remote_key_column
    return Webhookdb::Services::Column.new(:external_id, TEXT, data_key: "Id")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:active_in_theranest, BOOLEAN, data_key: "IsActive"),
      Webhookdb::Services::Column.new(:full_name, TEXT, data_key: "FullName"),
      Webhookdb::Services::Column.new(:updated_at, TIMESTAMP, optional: true, defaulter: :now),
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

  def _fetch_backfill_page(pagination_token, **_kwargs)
    # need to first backfill active staff, then backfill inactive staff
    backfilling_active = pagination_token.nil?
    pagination_token ||= "/api/staff/getAll/active"
    url = self.theranest_api_url + pagination_token

    response = Webhookdb::Http.get(
      url,
      headers: self.theranest_auth_headers,
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
end
