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
        deleted_rows = sint.replicator.stale_row_deleter.run
        self.set_job_tags("#{sint.organization.key}_#{sint.table_name}" => deleted_rows)
      end
    end
  end
end
