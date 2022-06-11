# frozen_string_literal: true

require "webhookdb/message/template"

class Webhookdb::Messages::OrgDatabaseMigrationStarted < Webhookdb::Message::Template
  def self.fixtured(recipient)
    dbm = Webhookdb::Fixtures.organization_database_migration.with_urls.started.create
    Webhookdb::Fixtures.organization_membership.org(dbm.organization).customer(recipient).verified.admin.create
    return self.new(dbm)
  end

  def initialize(org_database_migration)
    @org_database_migration = org_database_migration
    super()
  end

  def liquid_drops
    return super.merge(
      org_name: @org_database_migration.organization.name,
      source_host: @org_database_migration.displaysafe_source_url,
      destination_host: @org_database_migration.displaysafe_destination_url,
    )
  end
end
