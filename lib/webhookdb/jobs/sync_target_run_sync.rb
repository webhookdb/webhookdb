# frozen_string_literal: true

require "amigo/backoff_job"
require "webhookdb/async/job"

class Webhookdb::Jobs::SyncTargetRunSync
  extend Webhookdb::Async::Job
  include Amigo::BackoffJob

  sidekiq_options queue: "netout"

  def dependent_queues
    return ["critical"]
  end

  def perform(sync_target_id)
    (stgt = Webhookdb::SyncTarget[sync_target_id]) or raise "no sync target with id #{sync_target_id}"
    Webhookdb::Async::JobLogger.with_log_tags(
      sync_target_id: stgt.id,
      sync_target_connection_url: stgt.displaysafe_connection_url,
      sync_target_service_integration_service: stgt.service_integration.service_name,
      sync_target_service_integration_table: stgt.service_integration.table_name,
    ) do
      stgt.run_sync(at: Time.now)
    rescue Webhookdb::SyncTarget::SyncInProgress
      Webhookdb::Async::JobLogger.logger.warn("sync_target_already_in_progress")
    end
  end
end
