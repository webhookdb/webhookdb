# frozen_string_literal: true

require "webhookdb/replicator/transistor_v1_mixin"

class Webhookdb::Replicator::TransistorEpisodeV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::TransistorV1Mixin

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "transistor_episode_v1",
      ctor: ->(sint) { Webhookdb::Replicator::TransistorEpisodeV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "Transistor Episode",
    )
  end

  def analytics_table_name
    return "#{self.service_integration.table_name}_stats".to_sym
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:author, TEXT, data_key: ["attributes", "author"]),
      Webhookdb::Replicator::Column.new(
        :created_at,
        TIMESTAMP,
        index: true,
        data_key: ["attributes", "created_at"],
      ),
      Webhookdb::Replicator::Column.new(:duration, INTEGER, data_key: ["attributes", "duration"]),
      Webhookdb::Replicator::Column.new(:keywords, TEXT, data_key: ["attributes", "keywords"]),
      Webhookdb::Replicator::Column.new(:number, INTEGER, index: true, data_key: ["attributes", "number"]),
      Webhookdb::Replicator::Column.new(
        :published_at,
        TIMESTAMP,
        index: true,
        data_key: ["attributes", "published_at"],
      ),
      Webhookdb::Replicator::Column.new(:season, INTEGER, index: true, data_key: ["attributes", "season"]),
      Webhookdb::Replicator::Column.new(
        :show_id,
        TEXT,
        index: true,
        data_key: ["relationships", "show", "data", "id"],
      ),
      Webhookdb::Replicator::Column.new(:status, TEXT, data_key: ["attributes", "status"]),
      Webhookdb::Replicator::Column.new(:title, TEXT, data_key: ["attributes", "title"]),
      Webhookdb::Replicator::Column.new(:type, TEXT, data_key: ["attributes", "type"]),
      Webhookdb::Replicator::Column.new(
        :updated_at,
        TIMESTAMP,
        index: true,
        data_key: ["attributes", "updated_at"],
      ),
    ]
  end

  def upsert_has_deps?
    return true
  end

  def parse_date_from_api(date_string)
    return Time.strptime(date_string, "%d-%m-%Y")
  end

  def _fetch_backfill_page(pagination_token, last_backfilled:)
    url = "https://api.transistor.fm/v1/episodes"
    pagination_token = 1 if pagination_token.blank?
    response = Webhookdb::Http.get(
      url,
      headers: {"x-api-key" => self.service_integration.backfill_key},
      body: {pagination: {page: pagination_token}},
      logger: self.logger,
    )
    data = response.parsed_response
    episodes = data["data"]
    current_page = data["meta"]["currentPage"]
    total_pages = data["meta"]["totalPages"]
    next_page = (current_page.to_i + 1 if current_page < total_pages)

    if last_backfilled.present?
      earliest_data_created = episodes.empty? ? Time.at(0) : episodes[-1].dig("attributes", "created_at")
      paged_to_already_seen_records = earliest_data_created < last_backfilled

      return episodes, nil if paged_to_already_seen_records
    end

    return episodes, next_page
  end
end
