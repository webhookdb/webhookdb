# frozen_string_literal: true

require "amigo/queue_backoff_job"
require "amigo/durable_job"
require "webhookdb/async/job"
require "webhookdb/jobs"

class Webhookdb::Jobs::Backfill
  extend Webhookdb::Async::Job
  include Amigo::DurableJob
  include Amigo::QueueBackoffJob

  on "webhookdb.serviceintegration.backfill"
  sidekiq_options queue: "netout"

  def dependent_queues
    # This is really the lowest-priority job so always defer to other queues.
    return super
  end

  def _perform(event)
    sint = self.lookup_model(Webhookdb::ServiceIntegration, event.payload[0])
    svc = Webhookdb::Replicator.create(sint)
    backfill_kwargs = event.payload[1] || {}
    svc.backfill(**backfill_kwargs.symbolize_keys)
  end
end
