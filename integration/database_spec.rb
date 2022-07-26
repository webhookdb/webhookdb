# frozen_string_literal: true

RSpec.describe "database", :integration do
  it "can run a sync target" do
    org = Webhookdb::Fixtures.organization.create
    org.prepare_database_connections
    sint = Webhookdb::Fixtures.service_integration(organization: org).create
    sint.service_instance.create_table
    Array.new(5) do |i|
      t = (Time.now - i.days).iso8601
      sint.service_instance.upsert_webhook(body: {"my_id" => i.to_s, "at" => t})
    end
    dbinfo = Webhookdb::Organization::DbBuilder.new(org).prepare_database_connections
    sync_tgt = Webhookdb::Fixtures.sync_target(service_integration: sint, connection_url: dbinfo.admin_url).create
    require "webhookdb/jobs/sync_target_run_sync"
    Webhookdb::Jobs::SyncTargetRunSync.perform_async(sync_tgt.id)
    expect { sync_tgt.refresh }.to eventually(have_attributes(last_synced_at: be_present))
    Sequel.connect(dbinfo.readonly_url) do |db|
      expect(db[sint.table_name.to_sym].all).to have_attributes(size: 5)
    end
  end

  it "can run a database migration" do
    org = Webhookdb::Fixtures.organization.create
    org.prepare_database_connections
    sint = Webhookdb::Fixtures.service_integration(organization: org).create
    sint.service_instance.create_table
    Array.new(5) do |i|
      t = (Time.now + i.days).iso8601
      sint.service_instance.upsert_webhook(body: {"my_id" => i.to_s, "at" => t})
    end
    dbinfo = Webhookdb::Organization::DbBuilder.new(org).prepare_database_connections
    dbmigration = with_async_publisher do
      Webhookdb::Organization::DatabaseMigration.enqueue(
        admin_connection_url_raw: dbinfo.admin_url,
        readonly_connection_url_raw: dbinfo.readonly_url,
        public_host: org.public_host,
        started_by: nil,
        organization: org,
      )
    end
    expect { dbmigration.refresh }.to eventually(have_attributes(status: "finished"))
    Sequel.connect(dbinfo.readonly_url) do |db|
      expect(db[Sequel[org.replication_schema.to_sym][sint.table_name.to_sym]].all).to have_attributes(size: 5)
    end
  end
end
