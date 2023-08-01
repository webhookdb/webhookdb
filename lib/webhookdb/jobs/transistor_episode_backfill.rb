# frozen_string_literal: true

require "webhookdb/async/scheduled_job"
require "webhookdb/jobs"
require "webhookdb/transistor"

class Webhookdb::Jobs::TransistorEpisodeBackfill
  extend Webhookdb::Async::ScheduledJob

  cron(Webhookdb::Transistor.episode_cron_expression)
  splay 2.minutes

  def _perform
    Webhookdb::ServiceIntegration.dataset.where_each(service_name: "transistor_episode_v1") do |sint|
      Webhookdb::BackfillJob.create_recursive(service_integration: sint, incremental: true).enqueue
    end
  end
end
