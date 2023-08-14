# frozen_string_literal: true

require "webhookdb/async/scheduled_job"
require "webhookdb/jobs"

class Webhookdb::Jobs::IcalendarEnqueueSyncs
  extend Webhookdb::Async::ScheduledJob

  cron "* */30 * * * *" # Every 30 minutes
  splay 30

  def _perform
    Webhookdb::ServiceIntegration.dataset.where_each(service_name: "icalendar_calendar_v1") do |sint|
      sint.replicator.admin_dataset do |ds|
        sint.replicator.rows_needing_sync(ds).each do |row|
          calendar_external_id = row.fetch(:external_id)
          self.with_log_tags(sint.log_tags) do
            enqueued_job_id = Webhookdb::Jobs::IcalendarSync.perform_async(sint.id, calendar_external_id)
            self.logger.info("enqueued_icalendar_sync", calendar_external_id:, enqueued_job_id:)
          end
        end
      end
    end
  end
end
