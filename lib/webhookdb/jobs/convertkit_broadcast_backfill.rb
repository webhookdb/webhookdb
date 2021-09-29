# frozen_string_literal: true

require "webhookdb/async/scheduled_job"
require "webhookdb/jobs"

class Webhookdb::Jobs::ConvertkitBroadcastBackfill
  extend Webhookdb::Async::ScheduledJob

  cron "0 10 * * * *"
  splay 10.minutes

  def _perform
    Webhookdb::ServiceIntegration.dataset.where_each(service_name: "convertkit_broadcast_v1") do |sint|
      sint.publish_immediate("backfill", sint.id)
    end
  end
end
