# frozen_string_literal: true

require "webhookdb/replicator/transistor_v1_mixin"

class Webhookdb::Replicator::TransistorEpisodeStatsV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::TransistorV1Mixin

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "transistor_episode_stats_v1",
      ctor: ->(sint) { Webhookdb::Replicator::TransistorEpisodeStatsV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "Transistor Episode Stats",
      resource_name_plural: "Transistor Episode Stats",
      dependency_descriptor: Webhookdb::Replicator::TransistorEpisodeV1.descriptor,
      supports_backfill: true,
    )
  end

  CONV_PARSE_DMY_DASH = Webhookdb::Replicator::Column::IsomorphicProc.new(
    ruby: lambda do |s, **_|
      return Date.strptime(s, "%d-%m-%Y")
    rescue TypeError, Date::Error
      return nil
    end,
    sql: ->(e) { Sequel.function(:to_date, e, "DD-MM-YYYY") },
  )

  CONV_REMOTE_KEY = Webhookdb::Replicator::Column::IsomorphicProc.new(
    ruby: ->(_, resource:, **_) { "#{resource.fetch('episode_id')}-#{resource.fetch('date')}" },
    # Because this is a non-nullable key, we never need this in SQL
    sql: ->(_) { Sequel.lit("'do not use'") },
  )

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(
      :compound_identity,
      TEXT,
      data_key: "<compound key, see converter>",
      index: true,
      optional: true,
      converter: CONV_REMOTE_KEY,
    )
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:episode_id, TEXT),
      Webhookdb::Replicator::Column.new(:date, DATE, converter: CONV_PARSE_DMY_DASH),
      Webhookdb::Replicator::Column.new(:downloads, INTEGER),
      Webhookdb::Replicator::Column.new(:row_updated_at, TIMESTAMP, defaulter: :now, optional: true),
    ]
  end

  def _timestamp_column_name
    return :row_updated_at
  end

  def _resource_and_event(request)
    return request.body, nil
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:downloads] !~ Sequel[:excluded][:downloads]
  end

  def calculate_backfill_state_machine
    if (step = self.calculate_dependency_state_machine_step(dependency_help: ""))
      return step
    end
    step = Webhookdb::Replicator::StateMachineStep.new
    step.output = %(Great! That's all the information we need.
When your Transistor Episodes get added or updated, their stats will be updated in WebhookDB too.

#{self._query_help_output})
    return step.completed
  end

  def _backfillers
    episode_svc = self.service_integration.depends_on.replicator
    backfillers = episode_svc.admin_dataset(timeout: :fast) do |episode_ds|
      episode_ds.select(:transistor_id, :created_at).map do |episode|
        EpisodeStatsBackfiller.new(
          episode_svc:,
          episode_stats_svc: self,
          episode_id: episode[:transistor_id],
          episode_created_at: episode[:created_at],
        )
      end
    end
    return backfillers
  end

  class EpisodeStatsBackfiller < Webhookdb::Backfiller
    def initialize(episode_svc:, episode_stats_svc:, episode_id:, episode_created_at:)
      @episode_svc = episode_svc
      @episode_stats_svc = episode_stats_svc
      @episode_id = episode_id
      @episode_created_at = episode_created_at
      super()
    end

    def handle_item(item)
      item["episode_id"] = @episode_id
      @episode_stats_svc.upsert_webhook_body(item)
    end

    def fetch_backfill_page(_pagination_token, **_kwargs)
      analytics_url = "https://api.transistor.fm/v1/analytics/episodes/" + @episode_id
      # The "downloads" stat gets collected daily but will not change retroactively for a past date.
      # If there are already rows in the enrichment table matching the episode_id, we want to check
      # the date of the last entry so that we don't have to upsert information that we know will not
      # be changed. We allow for a two day buffer before the date of the last entry to account for changes
      # that may occur on the day of a new entry, while the downloads are accruing.
      latest_update = @episode_stats_svc.admin_dataset(timeout: :fast) do |ds|
        ds.where(episode_id: @episode_id).max(:date)
      end
      start_date = latest_update.nil? ? @episode_created_at : (latest_update - 2.days)
      request_body = {
        start_date: start_date.strftime("%d-%m-%Y"),
        end_date: Time.now.strftime("%d-%m-%Y"),
      }
      response = Webhookdb::Http.get(
        analytics_url,
        headers: {"x-api-key" => @episode_svc.service_integration.backfill_key},
        body: request_body,
        logger: @episode_stats_svc.logger,
        timeout: Webhookdb::Transistor.http_timeout,
      )
      data = response.parsed_response.dig("data", "attributes", "downloads") || []
      return data, nil
    end
  end
end
