# frozen_string_literal: true

require "time"
require "webhookdb/convertkit"
require "webhookdb/services/convertkit_v1_mixin"

class Webhookdb::Services::ConvertkitBroadcastV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::ConvertkitV1Mixin

  # @return [Webhookdb::Services::Descriptor]
  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "convertkit_broadcast_v1",
      ctor: ->(sint) { Webhookdb::Services::ConvertkitBroadcastV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "ConvertKit Broadcast",
    )
  end

  def calculate_create_state_machine
    return self.calculate_backfill_state_machine
  end

  def _create_enrichment_tables_sql
    return nil
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:click_rate, "numeric"),
      Webhookdb::Services::Column.new(:created_at, "timestamptz", index: true),
      Webhookdb::Services::Column.new(:open_rate, "numeric"),
      Webhookdb::Services::Column.new(:progress, "numeric"),
      Webhookdb::Services::Column.new(:recipients, "integer"),
      Webhookdb::Services::Column.new(:show_total_clicks, "boolean"),
      Webhookdb::Services::Column.new(:status, "text"),
      Webhookdb::Services::Column.new(:subject, "text"),
      Webhookdb::Services::Column.new(:total_clicks, "integer"),
      Webhookdb::Services::Column.new(:unsubscribes, "integer"),
    ]
  end

  def _update_where_expr
    return Sequel[self.table_sym][:data] !~ Sequel[:excluded][:data]
  end

  def _fetch_enrichment(body)
    broadcast_id = body.fetch("id")
    url = "https://api.convertkit.com/v3/broadcasts/#{broadcast_id}/stats?api_secret=#{self.service_integration.backfill_secret}"
    Kernel.sleep(Webhookdb::Convertkit.sleep_seconds)
    response = Webhookdb::Http.get(url, logger: self.logger)
    data = response.parsed_response
    return data.dig("broadcast", "stats") || {}
  end

  def _prepare_for_insert(body, enrichment:)
    # we aren't using `fetch` on the enrichment kwarg here because `fetch` throws an error
    # when a key is not present, and implementing fetch here would require us to rework our
    # base shared examples (e.g. `a service implementation`, `a service implementation that can
    # backfill`, etc.) to account for the possible presence of an enrichment object in order to
    # avoid those errors
    return {
      convertkit_id: body.fetch("id"),
      created_at: body.fetch("created_at"),
      click_rate: enrichment["click_rate"],
      open_rate: enrichment["open_rate"],
      progress: enrichment["progress"],
      recipients: enrichment["recipients"],
      show_total_clicks: enrichment["show_total_clicks"],
      status: enrichment["status"],
      subject: body.fetch("subject"),
      total_clicks: enrichment["total_clicks"],
      unsubscribes: enrichment["unsubscribes"],
    }
  end

  def _fetch_backfill_page(_pagination_token, **_kwargs)
    # this endpoint does not have pagination support
    url = "https://api.convertkit.com/v3/broadcasts?api_secret=#{self.service_integration.backfill_secret}"
    response = Webhookdb::Http.get(url, logger: self.logger)
    data = response.parsed_response
    return data["broadcasts"], nil
  end
end
