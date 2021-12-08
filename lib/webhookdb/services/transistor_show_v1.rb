# frozen_string_literal: true

require "webhookdb/transistor"
require "webhookdb/services/transistor_v1_mixin"

class Webhookdb::Services::TransistorShowV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::TransistorV1Mixin

  def _mixin_name_singular
    return "Show"
  end

  def _mixin_name_plural
    return "Shows"
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:author, "text"),
      Webhookdb::Services::Column.new(:created_at, "timestamptz"),
      Webhookdb::Services::Column.new(:description, "text"),
      Webhookdb::Services::Column.new(:title, "text"),
      Webhookdb::Services::Column.new(:website, "text"),
      Webhookdb::Services::Column.new(:updated_at, "timestamptz"),
    ]
  end

  def _prepare_for_insert(body, **_kwargs)
    obj_of_interest = body.key?("data") ? body["data"] : body
    attributes = obj_of_interest.fetch("attributes")
    return {
      author: attributes.fetch("author"),
      created_at: attributes.fetch("created_at"),
      description: attributes.fetch("description"),
      title: attributes.fetch("title"),
      transistor_id: obj_of_interest.fetch("id"),
      updated_at: attributes.fetch("updated_at"),
      website: attributes.fetch("website"),
    }
  end

  def _fetch_backfill_page(pagination_token, **_kwargs)
    pagination_token ||= [false, 1]
    iterating_over_private, page = pagination_token

    url = "https://api.transistor.fm/v1/shows"

    response = Webhookdb::Http.get(
      url,
      headers: {"x-api-key" => self.service_integration.backfill_key},
      body: {pagination: {page: page}, private: iterating_over_private},
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
