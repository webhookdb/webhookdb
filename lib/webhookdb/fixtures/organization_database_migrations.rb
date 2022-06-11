# frozen_string_literal: true

require "webhookdb"
require "webhookdb/fixtures"

module Webhookdb::Fixtures::OrganizationDatabaseMigrations
  extend Webhookdb::Fixtures

  fixtured_class Webhookdb::Organization::DatabaseMigration

  base :organization_database_migration do
  end

  before_saving do |instance|
    instance.organization ||= Webhookdb::Fixtures.organization.create
    instance
  end

  decorator :started do |t=Time.now|
    self.started_at = t
  end

  decorator :finished do |t=Time.now|
    self.started_at ||= t
    self.finished_at = t
  end

  decorator :with_urls do
    self.source_admin_connection_url ||= "postgres://oldadmin:pass@oldhost.db:5432/old_db"
    self.destination_admin_connection_url ||= "postgres://newadmin:pass@newhost.db:5432/new_db"
  end
end
