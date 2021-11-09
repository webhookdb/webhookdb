# frozen_string_literal: true

require "time"
require "webhookdb/convertkit"

class Webhookdb::Services::ConvertkitBroadcastV1 < Webhookdb::Services::Base
  include Appydays::Loggable

  def _webhook_verified?(_request)
    # Webhooks aren't available for tags
    return true
  end

  def calculate_create_state_machine
    return self.calculate_backfill_state_machine
  end

  def calculate_backfill_state_machine
    step = Webhookdb::Services::StateMachineStep.new
    if self.service_integration.backfill_secret.blank?
      step.output = %(
Great! We've created your ConvertKit Broadcasts integration.

ConvertKit does not support Broadcast webhooks, so to fill your database,
we need to use the API to make requests, which requires your API Secret.
#{Webhookdb::Convertkit::FIND_API_SECRET_HELP}
      )
      return step.secret_prompt("API Secret").backfill_secret(self.service_integration)
    end
    step.output = %(
We'll start backfilling your ConvertKit Broadcasts now,
and they will show up in your database momentarily.
#{self._query_help_output}
      )
    return step.completed
  end

  def _create_enrichment_tables_sql
    return nil
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:convertkit_id, "bigint")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:click_rate, "real"),
      Webhookdb::Services::Column.new(:created_at, "timestamptz"),
      Webhookdb::Services::Column.new(:open_rate, "real"),
      Webhookdb::Services::Column.new(:progress, "real"),
      Webhookdb::Services::Column.new(:recipients, "integer"),
      Webhookdb::Services::Column.new(:show_total_clicks, "boolean"),
      Webhookdb::Services::Column.new(:status, "text"),
      Webhookdb::Services::Column.new(:subject, "text"),
      Webhookdb::Services::Column.new(:total_clicks, "integer"),
      Webhookdb::Services::Column.new(:unsubscribes, "integer"),
    ]
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
    return {
      convertkit_id: body["id"],
      created_at: body["created_at"],
      click_rate: enrichment["click_rate"],
      open_rate: enrichment["open_rate"],
      progress: enrichment["progress"],
      recipients: enrichment["recipients"],
      show_total_clicks: enrichment["show_total_clicks"],
      status: enrichment["status"],
      subject: body["subject"],
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
