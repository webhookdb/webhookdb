# frozen_string_literal: true

require "webhookdb/async/scheduled_job"
require "webhookdb/jobs"

# For every IcalendarCalendar row needing a sync (across all service integrations),
# enqueue a +Webhookdb::Jobs::IcalendarSync+ job.
# Jobs are 'splayed' over 1/4 of the configured calendar sync period (see +Webhookdb::Icalendar+)
# to avoid a thundering herd.
class Webhookdb::Jobs::IcalendarEnqueueSyncs
  extend Webhookdb::Async::ScheduledJob

  cron "*/30 * * * *" # Every 30 minutes
  splay 30

  def _perform
    max_splay = Webhookdb::Icalendar.sync_period_hours.hours.to_i / 4
    Webhookdb::ServiceIntegration.dataset.where_each(service_name: "icalendar_calendar_v1") do |sint|
      sint.replicator.admin_dataset do |ds|
        sint.replicator.rows_needing_sync(ds).each do |row|
          calendar_external_id = row.fetch(:external_id)
          self.with_log_tags(sint.log_tags) do
            splay = rand(1..max_splay)
            enqueued_job_id = Webhookdb::Jobs::IcalendarSync.perform_in(splay, sint.id, calendar_external_id)
            self.logger.debug("enqueued_icalendar_sync", calendar_external_id:, enqueued_job_id:)
          end
        end
      end
    end
  end
end
