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
      if Webhookdb::RACK_ENV == "staging"
        # We can end up with this race on staging, since we delete sync targets.
        # It's possible in other environments, and maybe skip it in all cases,
        # but for now it's just for staging.
        self.logger.warn("missing_sync_target", sync_target_id:)
        return
      end
      raise "no sync target with id #{sync_target_id}"
    end
    self.with_log_tags(
      sync_target_id: stgt.id,
      sync_target_connection_url: stgt.displaysafe_connection_url,
      sync_target_service_integration_service: stgt.service_integration.service_name,
      sync_target_service_integration_table: stgt.service_integration.table_name,
    ) do
      stgt.run_sync(now: Time.now)
    rescue Webhookdb::SyncTarget::SyncInProgress
      Webhookdb::Async::JobLogger.logger.warn("sync_target_already_in_progress")
    end
  end
end
