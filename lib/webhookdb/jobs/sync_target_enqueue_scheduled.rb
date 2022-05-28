# frozen_string_literal: true

require "webhookdb/async/job"

class Webhookdb::Jobs::SyncTargetEnqueueScheduled
  extend Webhookdb::Async::ScheduledJob

  cron "0 * * * * *"
  splay 0

  def _perform
    Webhookdb::SyncTarget.due_for_sync(as_of: Time.now).select(:id).each do |st|
      Webhookdb::Jobs::SyncTargetRunSync.perform_async(st.id)
    end
  end
end
