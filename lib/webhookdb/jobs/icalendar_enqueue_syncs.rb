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
# - This job runs every 30 minutes.
# - It finds rows never synced,
#   or haven't been synced in 8 hours (see +Webhookdb::Icalendar.sync_period_hours+
#   for the actual value, we'll assume 8 hours for this doc).
# - Enqueue a row sync sync job for between 1 second and 60 minutes from now
#   (see +Webhookdb::Icalendar.sync_period_splay_hours+ for actual upper bound value).
# - When the sync job runs, if the row has been synced less than 8 hours ago, the job noops.
#
# This design will lead to the same calendar being enqueued for a sync multiple times
# (for a splay of 1 hour, and running this job every 30 minutes, about half the jobs in the queue will be duplicate).
# This isn't a problem however, since the first sync will run but the duplicates will noop
# since the row will be seen as recently synced.
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
  cron "*/30 * * * *"
  splay 30

  def _perform
    self.advisory_lock.with_lock? do
      self.__perform
    end
  end

  # Just a random big number
  LOCK_ID = 2_161_457_251_202_716_167

  def advisory_lock
    return Sequel::AdvisoryLock.new(Webhookdb::Customer.db, LOCK_ID)
  end

  def __perform
    max_projected_out_seconds = Webhookdb::Icalendar.sync_period_splay_hours.hours.to_i
    total_count = 0
    threadpool = Concurrent::ThreadPoolExecutor.new(
      name: "ical-precheck",
      max_threads: Webhookdb::Icalendar.precheck_feed_change_pool_size,
      min_threads: 1,
      idletime: 40,
      max_queue: 0,
      fallback_policy: :caller_runs,
      synchronous: false,
    )
    Webhookdb::ServiceIntegration.dataset.where_each(service_name: "icalendar_calendar_v1") do |sint|
      sint_count = 0
      self.with_log_tags(sint.log_tags) do
        repl = sint.replicator
        repl.admin_dataset do |ds|
          row_ds = repl.
            rows_needing_sync(ds).
            order(:pk).
            select(:external_id, :ics_url, :last_fetch_context)
          row_ds.paged_each(rows_per_fetch: 500, cursor_name: "ical_enqueue_#{sint.id}_cursor") do |row|
            self.long_running_job_heartbeat!
            threadpool.post do
              break unless repl.feed_changed?(row)
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
