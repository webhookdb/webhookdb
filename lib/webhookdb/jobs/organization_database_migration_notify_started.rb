# frozen_string_literal: true

require "webhookdb/async/job"
require "webhookdb/messages/org_database_migration_started"

class Webhookdb::Jobs::OrganizationDatabaseMigrationNotifyStarted
  extend Webhookdb::Async::Job

  on "webhookdb.organization.databasemigration.updated"

  def _perform(event)
    dbm = self.lookup_model(Webhookdb::Organization::DatabaseMigration, event)
    case event.payload[1]
      when changed(:started_at, from: nil)
        Webhookdb::Idempotency.once_ever.under_key("org-dbmigration-start-#{dbm.id}") do
          msg = Webhookdb::Messages::OrgDatabaseMigrationStarted.new(dbm)
          dbm.organization.admin_customers.each { |c| msg.dispatch_email(c) }
        end
    end
  end
end
