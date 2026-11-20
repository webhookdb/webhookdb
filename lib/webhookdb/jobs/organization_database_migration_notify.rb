# frozen_string_literal: true

require "webhookdb/async/job"
require "webhookdb/messages/org_database_migration_finished"
require "webhookdb/messages/org_database_migration_started"

class Webhookdb::Jobs::OrganizationDatabaseMigrationNotify
  extend Webhookdb::Async::Job

  on "webhookdb.organization.databasemigration.updated"

  def _perform(event)
    dbm = self.lookup_model(Webhookdb::Organization::DatabaseMigration, event)
    self.set_job_tags(database_migration_id: dbm.id, organization: dbm.organization.key)
    case event.payload[1]
      when changed(:started_at, from: nil)
        Webhookdb::Idempotency.once_ever.under_key("org-dbmigration-start-#{dbm.id}") do
          msg = Webhookdb::Messages::OrgDatabaseMigrationStarted.new(dbm)
          dbm.organization.admin_customers.each { |c| msg.dispatch_email(c) }
        end
        self.set_job_tags(result: "started_message_sent")
      when changed(:finished_at, from: nil)
        Webhookdb::Idempotency.once_ever.under_key("org-dbmigration-finish-#{dbm.id}") do
          msg = Webhookdb::Messages::OrgDatabaseMigrationFinished.new(dbm)
          dbm.organization.admin_customers.each { |c| msg.dispatch_email(c) }
        end
        self.set_job_tags(result: "finished_message_sent")
      else
        self.set_job_tags(result: "noop")
    end
  end
end
