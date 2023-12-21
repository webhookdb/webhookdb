# frozen_string_literal: true

require "amigo/queue_backoff_job"
require "webhookdb/async/job"

class Webhookdb::Jobs::SyncTargetRunSync
  extend Webhookdb::Async::Job
  include Amigo::QueueBackoffJob

  sidekiq_options queue: "netout"

  def dependent_queues
    return ["critical"]
  end

  def perform(sync_target_id)
    stgt = Webhookdb::SyncTarget[sync_target_id]
    if stgt.nil?
      # A sync target may be enqueued, but destroyed before the sync runs.
      # If so, log a warning. We see this on staging a lot,
      # but it does happen on production too, and should be expected.
      self.logger.info("missing_sync_target", sync_target_id:)
      return
    end
    self.with_log_tags(
      sync_target_id: stgt.id,
      sync_target_connection_url: stgt.displaysafe_connection_url,
      sync_target_service_integration_service: stgt.service_integration.service_name,
      sync_target_service_integration_table: stgt.service_integration.table_name,
    ) do
      stgt.run_sync(now: Time.now)
    rescue Webhookdb::SyncTarget::SyncInProgress
      self.logger.info("sync_target_already_in_progress")
    rescue Webhookdb::SyncTarget::Deleted
      self.logger.info("sync_target_deleted")
    end
  end
end
