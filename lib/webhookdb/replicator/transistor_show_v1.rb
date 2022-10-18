# frozen_string_literal: true

require "webhookdb/services/transistor_v1_mixin"

class Webhookdb::Services::TransistorShowV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::TransistorV1Mixin

  # @return [Webhookdb::Services::Descriptor]
  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "transistor_show_v1",
      ctor: ->(sint) { Webhookdb::Services::TransistorShowV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "Transistor Show",
    )
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:author, TEXT, data_key: ["attributes", "author"]),
      Webhookdb::Services::Column.new(
        :created_at, TIMESTAMP,
        index: true,
        data_key: ["attributes", "created_at"],
      ),
      Webhookdb::Services::Column.new(:description, TEXT, data_key: ["attributes", "description"]),
      Webhookdb::Services::Column.new(:title, TEXT, data_key: ["attributes", "title"]),
      Webhookdb::Services::Column.new(
        :updated_at,
        TIMESTAMP,
        index: true,
        data_key: ["attributes", "updated_at"],
      ),
      Webhookdb::Services::Column.new(:website, TEXT, data_key: ["attributes", "website"]),
    ]
  end

  def _fetch_backfill_page(pagination_token, **_kwargs)
    pagination_token ||= [false, 1]
    iterating_over_private, page = pagination_token

    url = "https://api.transistor.fm/v1/shows"

    response = Webhookdb::Http.get(
      url,
      headers: {"x-api-key" => self.service_integration.backfill_key},
      body: {pagination: {page:}, private: iterating_over_private},
      logger: self.logger,
    )
    data = response.parsed_response
    current_page = data["meta"]["currentPage"]
    total_pages = data["meta"]["totalPages"]
    shows = data["data"]

    if current_page < total_pages
      # If we still have pages on this list, go to the next one
      return shows, [iterating_over_private, current_page + 1]
    end
    # If we are done with the public list, we can now iterate over private shows
    return shows, [true, 1] unless iterating_over_private
    # Otherwise we are on the last page of our private list
    return shows, nil
  end
end
