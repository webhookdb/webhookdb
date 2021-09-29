# frozen_string_literal: true

require "webhookdb/transistor"

class Webhookdb::Services::TransistorEpisodeV1 < Webhookdb::Services::Base
  include Appydays::Loggable

  def _webhook_verified?(_request)
    # As of 9/15/21 there is no way to verify authenticity of these webhooks
    return true
  end

  def process_state_change(field, value)
    self.service_integration.db.transaction do
      self.service_integration.send("#{field}=", value)
      self.service_integration.save_changes
      case field
        when "backfill_key"
          return self.calculate_backfill_state_machine(self.service_integration.organization)
      else
          return
      end
    end
  end

  def analytics_table_name
    return "#{self.service_integration.table_name}_stats"
  end

  def calculate_create_state_machine(organization)
    step = Webhookdb::Services::StateMachineStep.new
    step.needs_input = false
    step.output = %(
Great! We've created your Transistor Episodes Service Integration.
We will also include analytics data for each episode,
in the #{self.analytics_table_name} table.

You can query the database through your organization's Postgres connection string:

#{organization.readonly_connection_url}

You can also run a query through the CLI:

webhookdb db sql "SELECT * FROM #{self.service_integration.table_name}"
webhookdb db sql "SELECT * FROM #{self.analytics_table_name} WHERE date > '2021-01-15'"

Transistor's webhook support is spotty, so to fill your database,
we need to set up backfill functionality.

Run `webhookdb backfill #{self.service_integration.opaque_id}` to get started.
      )
    step.complete = true
    return step
  end

  def calculate_backfill_state_machine(_organization)
    step = Webhookdb::Services::StateMachineStep.new
    if self.service_integration.backfill_key.blank?
      step.needs_input = true
      step.output = %(
In order to backfill Transistor Episodoes, we need your API Key.

From your Transistor dashboard, go to the "Your Account" page,
at https://dashboard.transistor.fm/account
On the left side of the bottom of the page you should be able to see your API key.

Copy that API key.
      )
      step.prompt = "Paste or type your API key here:"
      step.prompt_is_secret = true
      step.post_to_url = "/v1/service_integrations/#{self.service_integration.opaque_id}/transition/backfill_key"
      step.complete = false
      return step
    end
    step.needs_input = false
    step.output = %(
Great! We are going to start backfilling your Transistor Episode information.
      )
    step.complete = true
    return step
  end

  def _create_enrichment_tables_sql
    tbl = self.analytics_table_name
    return %(
CREATE TABLE #{tbl} (pk bigserial PRIMARY KEY, date DATE, downloads INTEGER, episode_id TEXT);
CREATE INDEX date_idx ON #{tbl} (date);
CREATE INDEX episode_id_idx ON #{tbl} (episode_id);
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
      Webhookdb::Services::Column.new(:type, "text"),
      Webhookdb::Services::Column.new(:updated_at, "timestamptz"),

    ]
  end

  def _fetch_enrichment(body)
    obj_of_interest = body.key?("data") ? body["data"] : body
    episode_id = obj_of_interest.fetch("id")
    analytics_url = "https://api.transistor.fm/v1/analytics/episodes/" + episode_id
    created_at = obj_of_interest.fetch("attributes").fetch("created_at")
    request_body = {
      start_date: Time.parse(created_at).strftime("%d-%m-%Y"),
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
    return {
      author: obj_of_interest["attributes"]["author"],
      created_at: obj_of_interest["attributes"]["created_at"],
      duration: obj_of_interest["attributes"]["duration"],
      keywords: obj_of_interest["attributes"]["keywords"],
      number: obj_of_interest["attributes"]["number"],
      published_at: obj_of_interest["attributes"]["published_at"],
      season: obj_of_interest["attributes"]["season"],
      status: obj_of_interest["attributes"]["status"],
      title: obj_of_interest["attributes"]["title"],
      transistor_id: obj_of_interest["id"],
      type: obj_of_interest["attributes"]["type"],
      updated_at: obj_of_interest["attributes"]["updated_at"],
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
    self.admin_dataset(&:db)[self.analytics_table_name.to_sym].multi_insert(rows)
  end

  def parse_date_from_api(date_string)
    return Time.strptime(date_string, "%d-%m-%Y")
  end

  def _fetch_backfill_page(pagination_token)
    url = "https://api.transistor.fm/v1/episodes"
    pagination_token = 1 if pagination_token.blank?
    response = Webhookdb::Http.get(
      url,
      headers: {"x-api-key" => self.service_integration.backfill_key},
      body: {pagination: {page: pagination_token}},
      logger: self.logger,
    )
    data = response.parsed_response
    current_page = data["meta"]["currentPage"]
    total_pages = data["meta"]["totalPages"]
    next_page = (current_page.to_i + 1 if current_page < total_pages)
    return data["data"], next_page
  end
end
