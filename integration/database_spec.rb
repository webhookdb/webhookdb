# frozen_string_literal: true

RSpec.describe "database", :integration do
  def setup_integration_with_data(rows)
    org = Webhookdb::Fixtures.organization.create
    org.prepare_database_connections
    sint = Webhookdb::Fixtures.service_integration(organization: org).create
    sint.replicator.create_table
    Array.new(rows) do |i|
      t = (Time.now - i.days).iso8601
      sint.replicator.upsert_webhook_body({"my_id" => i.to_s, "at" => t})
    end
    Webhookdb::Organization::DbBuilder.new(org).prepare_database_connections
    return sint
  end

  it "can sync to database sync targets" do
    sint = setup_integration_with_data(5)
    sync_tgt = Webhookdb::Fixtures.sync_target(
      service_integration: sint,
      connection_url: sint.organization.admin_connection_url,
    ).create
    @to_destroy << sync_tgt
    require "webhookdb/jobs/sync_target_run_sync"
    Webhookdb::Jobs::SyncTargetRunSync.perform_async(sync_tgt.id)
    expect { sync_tgt.refresh }.to eventually(have_attributes(last_synced_at: be_present))
    Sequel.connect(sint.organization.readonly_connection_url) do |db|
      expect(db[sint.table_name.to_sym].all).to have_attributes(size: 5)
    end
  end

  it "can sync to http sync targets" do
    sint = setup_integration_with_data(5)
    sync_tgt = Webhookdb::Fixtures.sync_target(
      service_integration: sint,
      connection_url: "http://u:p@localhost:18015/mypath",
    ).create
    @to_destroy << sync_tgt

    require "socket"
    server = TCPServer.new "localhost", 18_015
    received = []
    server_thread = Thread.new do
      # Will only have one session
      session = server.accept
      # Processing line by line isn't needed here, we're just testing so grab the whole body
      received << session.recv(4096)
      session.print "HTTP/1.1 200\r\n"
      session.print "Content-Type: text/plain\r\n"
      session.print "\r\n"
      session.print "ok"
      session.close
    end

    # We need to do this in-process so the sync can POST back to localhost;
    # if the worker was on another machine, the tcp server wouldn't be reachable.
    sync_tgt.run_sync(now: Time.now)
    expect { sync_tgt.refresh }.to eventually(have_attributes(last_synced_at: be_present))
    expect { received }.to eventually(contain_exactly(include("POST /mypath").and(include('"rows":'))))
    Thread.kill(server_thread)
  end

  it "can run a database migration" do
    sint = setup_integration_with_data(5)
    org = sint.organization
    dbmigration = with_async_publisher do
      Webhookdb::Organization::DatabaseMigration.enqueue(
        admin_connection_url_raw: org.admin_connection_url,
        readonly_connection_url_raw: org.readonly_connection_url,
        public_host: org.public_host,
        started_by: nil,
        organization: org,
      )
    end
    expect { dbmigration.refresh }.to eventually(have_attributes(status: "finished"))
    Sequel.connect(org.readonly_connection_url) do |db|
      expect(db[Sequel[org.replication_schema.to_sym][sint.table_name.to_sym]].all).to have_attributes(size: 5)
    end
  end
end
