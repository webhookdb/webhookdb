# frozen_string_literal: true

require "amigo/queue_backoff_job"
require "webhookdb/async/job"

class Webhookdb::Jobs::SyncTargetRunSync
  extend Webhookdb::Async::Job
  include Amigo::QueueBackoffJob

  sidekiq_options queue: "netout"

  def dependent_queues = ["critical"]

  def perform(sync_target_id)
    stgt = Webhookdb::SyncTarget[sync_target_id]
    if stgt.nil?
      # A sync target may be enqueued, but destroyed before the sync runs.
      # If so, log a warning. We see this on staging a lot,
      # but it does happen on production too, and should be expected.
      self.set_job_tags(result: "missing_sync_target", sync_target_id:)
      return
    end
    self.set_job_tags(stgt.log_tags)
    begin
      started = Time.now
      stgt.run_sync(now: started)
      self.set_job_tags(result: "sync_target_synced", synced_at_of: started)
    rescue Webhookdb::SyncTarget::SyncInProgress
      self.set_job_tags(result: "sync_target_already_in_progress")
    rescue Webhookdb::SyncTarget::Deleted
      self.set_job_tags(result: "sync_target_deleted")
    end
  end
end
