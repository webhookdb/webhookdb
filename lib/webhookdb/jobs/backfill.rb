# frozen_string_literal: true

require "amigo/queue_backoff_job"
require "amigo/durable_job"
require "webhookdb/async/job"
require "webhookdb/jobs"

class Webhookdb::Jobs::Backfill
  extend Webhookdb::Async::Job
  include Amigo::DurableJob
  include Amigo::QueueBackoffJob

  on "webhookdb.backfilljob.run"
  sidekiq_options queue: "netout"

  def dependent_queues
    # This is really the lowest-priority job so always defer to other queues.
    return super
  end

  def _perform(event)
    begin
      bfjob = self.lookup_model(Webhookdb::BackfillJob, event.payload)
    rescue RuntimeError => e
      self.logger.info "skipping_missing_backfill_job", error: e
      return
    end
    sint = bfjob.service_integration
    bflock = bfjob.ensure_service_integration_lock
    self.with_log_tags(sint.log_tags.merge(backfill_job_id: bfjob.opaque_id)) do
      sint.db.transaction do
        unless bflock.lock?
          self.logger.info "skipping_locked_backfill_job"
          bfjob.update(finished_at: Time.now)
          break
        end
        bfjob.refresh
        if bfjob.finished?
          self.logger.info "skipping_finished_backfill_job"
          break
        end
        begin
          sint.replicator.backfill(bfjob)
        rescue Webhookdb::Replicator::CredentialsMissing
          # The credentials could have been cleared out, so just finish this job.
          self.logger.info "skipping_backfill_job_without_credentials"
          bfjob.update(finished_at: Time.now)
          break
        end
      end
    end
  end
end
