# frozen_string_literal: true

require "webhookdb/async/job"

class Webhookdb::Jobs::SyncTargetEnqueueScheduled
  extend Webhookdb::Async::ScheduledJob

  cron "*/1 * * * *"
  splay 0

  def _perform
    count = 0
    Webhookdb::SyncTarget.due_for_sync(as_of: Time.now).select(:id, :period_seconds).each do |st|
      count += 1
      Webhookdb::Jobs::SyncTargetRunSync.perform_in(st.jitter, st.id)
    end
    self.set_job_tags(enqueued_count: count)
  end
end
