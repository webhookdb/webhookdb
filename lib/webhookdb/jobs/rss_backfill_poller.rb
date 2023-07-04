# frozen_string_literal: true

require "webhookdb/async/scheduled_job"
require "webhookdb/jobs"

# RSS feeds don't generally update more than every hour.
# Poll all the 'simple' feeds hourly by enqueing a backfill.
class Webhookdb::Jobs::RssBackfillPoller
  extend Webhookdb::Async::ScheduledJob

  cron "11 * * * *" # At minute 11
  splay 5.seconds

  SERVICES = ["atom_single_feed_v1"].freeze

  def _perform
    Webhookdb::ServiceIntegration.dataset.where_each(service_name: SERVICES) do |sint|
      Webhookdb::BackfillJob.create(service_integration: sint, incremental: true).enqueue
    end
  end
end
