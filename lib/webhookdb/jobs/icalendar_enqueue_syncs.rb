# frozen_string_literal: true

require "webhookdb/async/scheduled_job"
require "webhookdb/jobs"

# For every IcalendarCalendar row needing a sync (across all service integrations),
# enqueue a +Webhookdb::Jobs::IcalendarSync+ job.
#
# Because icalendars need to be synced periodically,
# and there can be quite a lot, we have to be clever with how we sync them to both avoid syncing too often,
# and especially avoid saturating workers with syncs.
# We also have to handle workers running behind, the app being slow, etc.
#
# - This job runs every 60 minutes.
# - It finds rows never synced,
#   or haven't been synced in 8 hours (see +Webhookdb::Icalendar.sync_period_hours+
#   for the actual value, we'll assume 8 hours for this doc).
# - Enqueue a row sync sync job for between 1 second and 60 minutes from now.
# - When the sync job runs, if the row has been synced less than 8 hours ago, the job noops.
#
# In the best case scenario, all the enqueued rows are synced in the 60 minutes
# since the job ran last, and none are found.
#
# In the worse scenarios, many of the calendar rows didn't get processed in time,
# and show up on the next run.
# In this case, the same row could be enqueued multiple times,
# but will only run once, because the actual sync job will noop
# if the row is recently synced.
#
# Importantly, if there is a thundering herd situation,
# because there is a massive traunch of rows that need to be synced,
# and it takes maybe 10 hours to sync rather than one,
# the herd will be thinned and smeared over time as each row is synced.
# There isn't much we can do for the initial herd (other than making sure
# only some number of syncs are processing for a given org at a time)
# but we won't keep getting thundering herds from the same calendars over time.
class Webhookdb::Jobs::IcalendarEnqueueSyncs
  extend Webhookdb::Async::ScheduledJob

  # See docs for explanation of why we run this often.
  cron "*/60 * * * *"
  splay 30

  def _perform
    # See job doc for why we project out to 1/4 of the sync period,
    # rather than the whole period.
    max_projected_out_seconds = Webhookdb::Icalendar.sync_period_hours.hours.to_i / 4
    total_count = 0
    threadpool = Concurrent::CachedThreadPool.new(
      name: "ical-precheck",
      max_queue: Webhookdb::Icalendar.precheck_feed_change_pool_size,
      fallback_policy: :caller_runs,
    )
    Webhookdb::ServiceIntegration.dataset.where_each(service_name: "icalendar_calendar_v1") do |sint|
      sint_count = 0
      self.with_log_tags(sint.log_tags) do
        sint.replicator.admin_dataset do |ds|
          sint.replicator.rows_needing_sync(ds).select(:external_id, :ics_url, :last_fetch_context).each do |row|
            threadpool.post do
              break unless sint.replicator.feed_changed?(row)
              calendar_external_id = row.fetch(:external_id)
              perform_in = rand(1..max_projected_out_seconds)
              enqueued_job_id = Webhookdb::Jobs::IcalendarSync.perform_in(perform_in, sint.id, calendar_external_id)
              self.logger.debug("enqueued_icalendar_sync", calendar_external_id:, enqueued_job_id:, perform_in:)
              sint_count += 1
            end
          end
        end
      end
      total_count += sint_count
      self.set_job_tags("#{sint.organization.key}_#{sint.table_name}" => sint_count)
    end
    threadpool.shutdown
    threadpool.wait_for_termination
    self.set_job_tags(total_enqueued: total_count)
  end
end
