# frozen_string_literal: true

require "webhookdb/transistor"

class Webhookdb::Services::TransistorEpisodeV1 < Webhookdb::Services::Base
  include Appydays::Loggable

  def _webhook_verified?(_request)
    # As of 9/15/21 there is no way to verify authenticity of these webhooks
    return true
  end

  def analytics_table_name
    return "#{self.service_integration.table_name}_stats"
  end

  def calculate_create_state_machine
    return self.calculate_backfill_state_machine
  end

  def calculate_backfill_state_machine
    step = Webhookdb::Services::StateMachineStep.new
    if self.service_integration.backfill_key.blank?
      step.output = %(
Great! We've created your Transistor Episodes integration.

Transistor does not support Episodes webhooks, so to fill your database,
we need to use the API to make requests, which requires your API Key.

From your Transistor dashboard, go to the "Your Account" page,
at https://dashboard.transistor.fm/account
On the left side of the bottom of the page you should be able to see your API key.

Copy that API key.
      )
      return step.secret_prompt("API Key").backfill_key(self.service_integration)
    end
    step.output = %(
Great! We are going to start backfilling your Transistor Episode information.

We will also include analytics data for each episode,
in the #{self.analytics_table_name} table.
#{self._query_help_output}
webhookdb db sql "SELECT * FROM #{self.analytics_table_name} WHERE date > '2021-01-15'"
      )
    return step.completed
  end

  def _create_enrichment_tables_sql
    tbl = self.analytics_table_name
    return %(
CREATE TABLE #{tbl} (pk bigserial PRIMARY KEY, date DATE, downloads INTEGER, episode_id TEXT);
CREATE UNIQUE INDEX date_episode_id_idx ON #{tbl} (date, episode_id);
      )
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:transistor_id, "text")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:author, "text"),
      Webhookdb::Services::Column.new(:created_at, "timestamptz"),
      Webhookdb::Services::Column.new(:duration, "integer"),
      Webhookdb::Services::Column.new(:keywords, "text"),
      Webhookdb::Services::Column.new(:number, "integer"),
      Webhookdb::Services::Column.new(:published_at, "timestamptz"),
      Webhookdb::Services::Column.new(:season, "integer"),
      Webhookdb::Services::Column.new(:status, "text"),
      Webhookdb::Services::Column.new(:title, "text"),
      Webhookdb::Services::Column.new(:show_id, "text"),
      Webhookdb::Services::Column.new(:type, "text"),
      Webhookdb::Services::Column.new(:updated_at, "timestamptz"),
    ]
  end

  def enrichment_tables
    return ["#{self.service_integration.table_name}_stats"]
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
    latest_update = self.admin_dataset(&:db)[self.analytics_table_name.to_sym].where(episode_id: episode_id).max(:date)
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

  def _update_where_expr
    return Sequel[self.table_sym][:updated_at] < Sequel[:excluded][:updated_at]
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
        episode_id: episode_id,
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