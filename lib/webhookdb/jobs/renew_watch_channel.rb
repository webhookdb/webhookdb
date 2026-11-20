# frozen_string_literal: true

require "amigo/queue_backoff_job"
require "webhookdb/async/job"
require "webhookdb/jobs"

# Generic helper to renew watch channels, enqueued by replicator-specific jobs
# like RenewGoogleWatchChannels.
# Must be emitted with [service_integration_id, {row_pk:, expirng_before:}]
# Calls #renew_watch_channel(row_pk:, expiring_before:).
class Webhookdb::Jobs::RenewWatchChannel
  extend Webhookdb::Async::Job
  include Amigo::QueueBackoffJob

  sidekiq_options queue: "netout"

  def perform(service_integration_id, renew_watch_criteria)
    sint = self.lookup_model(Webhookdb::ServiceIntegration, service_integration_id)
    self.set_job_tags(sint.log_tags)
    row_pk = renew_watch_criteria.fetch("row_pk")
    expiring_before = Time.parse(renew_watch_criteria.fetch("expiring_before"))
    sint.replicator.renew_watch_channel(row_pk:, expiring_before:)
  end
end
