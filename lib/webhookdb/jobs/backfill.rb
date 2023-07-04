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
    bfjob = self.lookup_model(Webhookdb::BackfillJob, event.payload)
    sint = bfjob.service_integration
    self.with_log_tags(sint.log_tags) do
      sint.replicator.backfill(bfjob)
    end
  end
end
