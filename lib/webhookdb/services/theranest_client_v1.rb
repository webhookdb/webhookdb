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

  def _remote_key_column
    return Webhookdb::Services::Column.new(:theranest_id, TEXT, data_key: "Id")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:archived_in_theranest, BOOLEAN, data_key: "IsArchived"),
      Webhookdb::Services::Column.new(
        :birth_date,
        DATE,
        data_key: "DateOfBirthYMD",
        converter: CONV_PARSE_YMD_SLASH,
      ),
      Webhookdb::Services::Column.new(
        :created_in_theranest_at,
        DATE,
        data_key: "RegistrationDateTimeYMD",
        converter: CONV_PARSE_YMD_SLASH,
      ),
      Webhookdb::Services::Column.new(:email, TEXT, data_key: "Email"),
      Webhookdb::Services::Column.new(:external_client_id, TEXT, data_key: "ClientIdNumber"),
      Webhookdb::Services::Column.new(
        :external_location_id,
        INTEGER,
        data_key: "LocationId",
        converter: Webhookdb::Services::Column::CONV_TO_I,
      ),
      Webhookdb::Services::Column.new(:full_name, TEXT, data_key: "FullName"),
      Webhookdb::Services::Column.new(:preferred_name, TEXT, data_key: "PreferredName"),
    ]
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:data] !~ Sequel[:excluded][:data]
  end

  def _timestamp_column_name
    return :created_in_theranest_at
  end

  def _verify_backfill_err_msg
    return "Looks like your auth cookie has expired."
  end

  def _fetch_backfill_page(pagination_token, **_kwargs)
    count = Webhookdb::Theranest.page_size
    offset = pagination_token.present? ? pagination_token : 0
    url = self.theranest_api_url + "/api/clients/listing"

    response = Webhookdb::Http.get(
      url,
      query: {
        take: count,
        skip: offset,
        fullNameSort: "asc",
      },
      headers: self.theranest_auth_headers,
      logger: self.logger,
    )
    data = response.parsed_response["Data"]
    return data, nil if data.size < count
    return data, offset + count
  end
end
