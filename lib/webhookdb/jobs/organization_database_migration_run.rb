# frozen_string_literal: true

require "amigo/durable_job"
require "webhookdb/async/job"

class Webhookdb::Jobs::OrganizationDatabaseMigrationRun
  extend Webhookdb::Async::Job
  include Amigo::DurableJob

  on "webhookdb.organization.databasemigration.created"

  def _perform(event)
    dbm = self.lookup_model(Webhookdb::Organization::DatabaseMigration, event)
    self.set_job_tags(organization: dbm.organization.key, database_migration_id: dbm.id)
    begin
      dbm.migrate
      self.set_job_tags(result: "migration_finished")
    rescue Webhookdb::Organization::DatabaseMigration::MigrationAlreadyFinished
      self.set_job_tags(result: "migration_already_finished")
    end
  end
end
