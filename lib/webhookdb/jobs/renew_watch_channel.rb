# frozen_string_literal: true

require "amigo/queue_backoff_job"
require "webhookdb/async/job"
require "webhookdb/jobs"

# Generic helper to renew watch channels, enqueued by replicator-specific jobs
# like RenewGoogleWatchChannels.
# Must be emitted with [service integration id, {row_pk:, expirng_before:}]
# Calls #renew_watch_channel(row_pk:, expiring_before:).
class Webhookdb::Jobs::RenewWatchChannel
  extend Webhookdb::Async::Job
  include Amigo::QueueBackoffJob

  on "webhookdb.serviceintegration.renewwatchchannel"
  sidekiq_options queue: "netout"

  def _perform(event)
    sint = self.lookup_model(Webhookdb::ServiceIntegration, event)
    self.with_log_tags(sint.log_tags) do
      opts = event.payload[1]
      row_pk = opts.fetch("row_pk")
      expiring_before = Time.parse(opts.fetch("expiring_before"))
      sint.replicator.renew_watch_channel(row_pk:, expiring_before:)
    end
  end
end
