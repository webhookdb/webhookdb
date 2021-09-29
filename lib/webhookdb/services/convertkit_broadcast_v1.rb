# frozen_string_literal: true

require "time"
require "webhookdb/convertkit"

class Webhookdb::Services::ConvertkitBroadcastV1 < Webhookdb::Services::Base
  include Appydays::Loggable

  def _webhook_verified?(_request)
    # Webhooks aren't available for tags
    return true
  end

  def process_state_change(field, value)
    self.service_integration.db.transaction do
      self.service_integration.send("#{field}=", value)
      self.service_integration.save_changes
      case field
        when "backfill_secret"
          return self.calculate_backfill_state_machine(self.service_integration.organization)
      else
          return
      end
    end
  end

  def calculate_create_state_machine(organization)
    step = Webhookdb::Services::StateMachineStep.new
    step.needs_input = false
    step.output = %(
Great! We've created your ConvertKit Broadcast Service Integration.

You can query the database through your organization's Postgres connection string:

#{organization.readonly_connection_url}

You can also run a query through the CLI:

webhookdb db sql "SELECT * FROM #{self.service_integration.table_name}"

ConvertKit's webhook support is spotty, so to fill your database,
we need to set up backfill functionality.

Run `webhookdb backfill #{self.service_integration.opaque_id}` to get started.
      )
    step.complete = true
    return step
  end

  def calculate_backfill_state_machine(_organization)
    step = Webhookdb::Services::StateMachineStep.new
    if self.service_integration.backfill_secret.blank?
      step.needs_input = true
      step.output = %(
In order to backfill ConvertKit Broadcasts, we need your API secret.

From your ConvertKit Dashboard, go to your advanced account settings,
at https://app.convertkit.com/account_settings/advanced_settings.
Under the API Header you should be able to see your API secret, just under your API Key.

Copy that API secret.
      )
      step.prompt = "Paste or type your API secret here:"
      step.prompt_is_secret = true
      step.post_to_url = "/v1/service_integrations/#{self.service_integration.opaque_id}/transition/backfill_secret"
      step.complete = false
      return step
    end
    step.needs_input = false
    step.output = %(
Great! We are going to start backfilling your ConvertKit Broadcast information.
      )
    step.complete = true
    return step
  end

  def _create_enrichment_tables_sql
    return nil
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:convertkit_id, "text")
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

  def _update_where_expr
    # The broadcast resource does not have an `updated_at` field
    return Sequel[self.table_sym][:created_at] < Sequel[:excluded][:created_at]
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

  def _fetch_backfill_page(_pagination_token)
    # this endpoint does not have pagination support
    url = "https://api.convertkit.com/v3/broadcasts?api_secret=#{self.service_integration.backfill_secret}"
    response = Webhookdb::Http.get(url, logger: self.logger)
    data = response.parsed_response
    return data["broadcasts"], nil
  end
end
