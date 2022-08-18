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

  def _remote_key_column
    return Webhookdb::Services::Column.new(:external_id, TEXT, data_key: "key")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:archived, TEXT, data_key: "isArchived"),
      Webhookdb::Services::Column.new(:formatted_name, TEXT, data_key: "label"),
      Webhookdb::Services::Column.new(
        :updated_at,
        TIMESTAMP,
        optional: true,
        defaulter: :now,
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
    url = self.theranest_api_url + "/api/appointments/GetFilterValues"

    response = Webhookdb::Http.get(
      url,
      headers: self.theranest_auth_headers,
      logger: self.logger,
    )
    data = response.parsed_response["ServiceTypes"]

    # this array contains a dummy entry, "* No Service Type *", for which there is no "key" (i.e. external_id).
    # We filter it out here.
    data = data.filter { |entry| entry.fetch("key").present? }

    return data, nil
  end
end
