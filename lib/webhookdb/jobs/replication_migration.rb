# frozen_string_literal: true

require "webhookdb/async/job"

class Webhookdb::Jobs::ReplicationMigration
  extend Webhookdb::Async::Job

  on "webhookdb.organization.migratereplication"

  def _perform(event)
    org = self.lookup_model(Webhookdb::Organization, event)
    org.migrate_replication_tables
  end
end
