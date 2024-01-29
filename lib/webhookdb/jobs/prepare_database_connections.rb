# frozen_string_literal: true

require "amigo/durable_job"
require "webhookdb/async/job"

class Webhookdb::Jobs::PrepareDatabaseConnections
  extend Webhookdb::Async::Job
  include Amigo::DurableJob

  on "webhookdb.organization.created"
  sidekiq_options queue: "critical"

  def _perform(event)
    org = self.lookup_model(Webhookdb::Organization, event)
    org.db.transaction do
      # If creating the public host fails, we end up with an orphaned database,
      # but that's not a big deal- we can eventually see it's empty/unlinked and drop it.
      org.prepare_database_connections(safe: true)
      org.create_public_host_cname(safe: true)
    end
  end
end
