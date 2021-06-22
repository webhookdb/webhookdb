# frozen_string_literal: true

require "webhookdb/async/job"

class Webhookdb::Jobs::PrepareDatabaseConnections
  extend Webhookdb::Async::Job

  on "webhookdb.organization.created"

  def _perform(event)
    org = self.lookup_model(Webhookdb::Organization, event)
    org.prepare_database_connections
  end
end
