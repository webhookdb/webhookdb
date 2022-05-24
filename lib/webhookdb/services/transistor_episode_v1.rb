# frozen_string_literal: true

require "webhookdb/transistor"
require "webhookdb/services/transistor_v1_mixin"

class Webhookdb::Services::TransistorEpisodeV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::TransistorV1Mixin

  # @return [Webhookdb::Services::Descriptor]
  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "transistor_episode_v1",
      ctor: ->(sint) { Webhookdb::Services::TransistorEpisodeV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "Transistor Episode",
    )
  end

  def analytics_table_name
    return "#{self.service_integration.table_name}_stats"
  end

  def _enrichment_tables_descriptors
    table = Webhookdb::DBAdapter::Table.new(name: self.analytics_table_name)
    episodeidcol = Webhookdb::DBAdapter::Column.new(name: :episode_id, type: TEXT)
    datecol = Webhookdb::DBAdapter::Column.new(name: :date, type: DATE)
    return [
      Webhookdb::DBAdapter::TableDescriptor.new(
        table:,
        columns: [
          Webhookdb::DBAdapter::Column.new(name: :pk, type: PKEY),
          datecol,
          Webhookdb::DBAdapter::Column.new(name: :downloads, type: INTEGER),
          episodeidcol,
        ],
        indices: [
          Webhookdb::DBAdapter::Index.new(
            name: :date_episode_id_idx,
            table:,
            targets: [datecol, episodeidcol],
            unique: true,
          ),
        ],
      ),
    ]
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:author, TEXT),
      Webhookdb::Services::Column.new(:created_at, TIMESTAMP, index: true),
      Webhookdb::Services::Column.new(:duration, INTEGER),
      Webhookdb::Services::Column.new(:keywords, TEXT),
      Webhookdb::Services::Column.new(:number, INTEGER, index: true),
      Webhookdb::Services::Column.new(:published_at, TIMESTAMP, index: true),
      Webhookdb::Services::Column.new(:season, INTEGER, index: true),
      Webhookdb::Services::Column.new(:status, TEXT),
      Webhookdb::Services::Column.new(:title, TEXT),
      Webhookdb::Services::Column.new(:show_id, TEXT, index: true),
      Webhookdb::Services::Column.new(:type, TEXT),
      Webhookdb::Services::Column.new(:updated_at, TIMESTAMP, index: true),
    ]
  end

  def enrichment_tables
    return ["#{self.service_integration.table_name}_stats"]
  end

  def upsert_has_deps?
    return true
  end

  def _fetch_enrichment(body)
    obj_of_interest = body.key?("data") ? body["data"] : body
    episode_id = obj_of_interest.fetch("id")
    analytics_url = "https://api.transistor.fm/v1/analytics/episodes/" + episode_id
    created_at = obj_of_interest.fetch("attributes").fetch("created_at")
    # The "downloads" stat gets collected daily but will not change retroactively for a past date.
    # If there are already rows in the enrichment table matching the episode_id, we want to check
    # the date of the last entry so that we don't have to upsert information that we know will not
    # be changed. We allow for a two day buffer before the date of the last entry to account for changes
    # that may occur on the day of a new entry, while the downloads are accruing.
    latest_update = self.admin_dataset(&:db)[self.analytics_table_name.to_sym].where(episode_id:).max(:date)
    start_date = latest_update.nil? ? Time.parse(created_at) : (latest_update - 2.days)
    request_body = {
      start_date: start_date.strftime("%d-%m-%Y"),
      end_date: Time.now.strftime("%d-%m-%Y"),
    }
    Kernel.sleep(Webhookdb::Transistor.sleep_seconds)
    response = HTTParty.get(
      analytics_url,
      headers: {"x-api-key" => self.service_integration.backfill_key},
      body: request_body,
      logger: self.logger,
    )
    Webhookdb::Http.check!(response)
    return response.parsed_response
  end

  def _prepare_for_insert(body, **_kwargs)
    obj_of_interest = body.key?("data") ? body["data"] : body
    attributes = obj_of_interest.fetch("attributes")
    return {
      author: attributes.fetch("author"),
      created_at: attributes.fetch("created_at"),
      duration: attributes.fetch("duration"),
      keywords: attributes.fetch("keywords"),
      number: attributes.fetch("number"),
      published_at: attributes.fetch("published_at"),
      season: attributes.fetch("season"),
      show_id: obj_of_interest.fetch("relationships").fetch("show").fetch("data").fetch("id"),
      status: attributes.fetch("status"),
      title: attributes.fetch("title"),
      transistor_id: obj_of_interest.fetch("id"),
      type: attributes.fetch("type"),
      updated_at: attributes.fetch("updated_at"),
    }
  end

  def _after_insert(inserting, enrichment:)
    download_entries = enrichment.dig("data", "attributes", "downloads") || []
    episode_id = inserting[:transistor_id]
    rows = download_entries.map do |ent|
      {
        date: parse_date_from_api(ent["date"]),
        downloads: ent["downloads"],
        episode_id:,
      }
    end
    self.admin_dataset(&:db)[self.analytics_table_name.to_sym].
      insert_conflict(target: [:date, :episode_id], update: {downloads: Sequel[:excluded][:downloads]}).
      multi_insert(rows)
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
