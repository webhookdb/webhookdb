# frozen_string_literal: true

require "amigo/durable_job"
require "webhookdb/async/job"

class Webhookdb::Jobs::OrganizationDatabaseMigrationRun
  extend Webhookdb::Async::Job
  include Amigo::DurableJob

  on "webhookdb.organization.databasemigration.created"

  def _perform(event)
    dbm = self.lookup_model(Webhookdb::Organization::DatabaseMigration, event)
    self.with_log_tags(
      organization_id: dbm.organization.id,
      organization_name: dbm.organization.name,
      organization_database_migration_id: dbm.id,
    ) do
      dbm.migrate
    end
  end
end
