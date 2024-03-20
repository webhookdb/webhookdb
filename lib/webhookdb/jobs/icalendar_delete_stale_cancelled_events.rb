# frozen_string_literal: true

require "webhookdb/async/scheduled_job"
require "webhookdb/jobs"

class Webhookdb::Jobs::IcalendarDeleteStaleCancelledEvents
  extend Webhookdb::Async::ScheduledJob

  cron "37 7 * * *" # Once a day
  splay 120

  def _perform
    Webhookdb::ServiceIntegration.where(service_name: "icalendar_event_v1").each do |sint|
      self.with_log_tags(sint.log_tags) do
        sint.replicator.delete_stale_cancelled_events
      end
    end
  end
end
