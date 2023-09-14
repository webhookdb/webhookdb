# frozen_string_literal: true

require "webhookdb/async/job"

class Webhookdb::Jobs::SyncTargetEnqueueScheduled
  extend Webhookdb::Async::ScheduledJob

  cron "*/1 * * * *"
  splay 0

  def _perform
    Webhookdb::SyncTarget.due_for_sync(as_of: Time.now).select(:id, :period_seconds).each do |st|
      Webhookdb::Jobs::SyncTargetRunSync.perform_in(st.jitter, st.id)
    end
  end
end
