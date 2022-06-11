# frozen_string_literal: true

RSpec.describe "Webhookdb::Organization::DatabaseMigration", :db do
  let(:described_class) { Webhookdb::Organization::DatabaseMigration }

  describe "datasets" do
    describe "ongoing" do
      it "returns unfinished migrations" do
        inited = Webhookdb::Fixtures.organization_database_migration.create
        started = Webhookdb::Fixtures.organization_database_migration.started.create
        finished = Webhookdb::Fixtures.organization_database_migration.finished.create
        expect(described_class.dataset.ongoing.all).to have_same_ids_as(inited, started)
      end
    end
  end

  it "can represent its urls" do
    dbm = Webhookdb::Fixtures.organization_database_migration.create(
      source_admin_connection_url: "postgres://admin:p@oldhost/db",
      destination_admin_connection_url: "postgres://ro:p@newhost/db",
    )
    expect(dbm).to have_attributes(
      displaysafe_source_url: "postgres://***:***@oldhost/db",
      displaysafe_destination_url: "postgres://***:***@newhost/db",
    )
  end

  describe "enqueue" do
    it "creates a database migration instance with the correct fields and updates the org" do
      cust = Webhookdb::Fixtures.customer.create
      org = Webhookdb::Fixtures.organization.create(
        replication_schema: "xyz",
        public_host: "olddns.db",
        admin_connection_url_raw: "postgres://admin:p@oldhost/db",
        readonly_connection_url_raw: "postgres://ro:p@oldhost/db",
      )
      Webhookdb::Fixtures.service_integration(organization: org, table_name: "table1").create
      Webhookdb::Fixtures.service_integration(organization: org, table_name: "table2").create
      dbm = described_class.enqueue(
        admin_connection_url_raw: "postgres://admin2:p@newhost/db",
        readonly_connection_url_raw: "postgres://ro2:p@newhost/db",
        public_host: "newhost.db",
        started_by: cust,
        organization: org,
      )
      expect(dbm).to have_attributes(
        started_by: be === cust,
        organization: be === org,
        started_at: nil,
        source_admin_connection_url: "postgres://admin:p@oldhost/db",
        destination_admin_connection_url: "postgres://admin2:p@newhost/db",
        organization_schema: "xyz",
      )
      expect(org).to have_attributes(
        admin_connection_url: "postgres://admin2:p@newhost.db/db",
        readonly_connection_url: "postgres://ro2:p@newhost.db/db",
        public_host: "newhost.db",
      )
    end

    it "errors if there is an ongoing migration" do
      org = Webhookdb::Fixtures.organization.create
      Webhookdb::Fixtures.organization_database_migration.started.create(organization: org)
      expect do
        described_class.enqueue(
          admin_connection_url_raw: "1",
          readonly_connection_url_raw: "2",
          public_host: "",
          started_by: nil,
          organization: org,
        )
      end.to raise_error(described_class::MigrationInProgress)
    end
  end

  describe "migrate" do
    let(:org) { Webhookdb::Fixtures.organization.create }
    let!(:sint1) { Webhookdb::Fixtures.service_integration(organization: org).create }
    let!(:sint2) { Webhookdb::Fixtures.service_integration(organization: org).create }
    let!(:sint_no_table) { Webhookdb::Fixtures.service_integration(organization: org).create }
    let(:t0) { Time.parse("2015-01-01T00:00:00Z") }
    let(:dbmigration) { @dbmigration }

    before(:each) do
      Webhookdb::Organization.database_migration_page_size = 10
      # Test setup here is a bear. We need to:
      # 1) Create the old database
      # 2) Insert data into the old database
      # 3) Prepare a *new* database
      # 4) In some tests, also insert data into the new database.
      org.prepare_database_connections
      sint1.service_instance.create_table
      sint2.service_instance.create_table
      Array.new(52) do |i|
        t = (t0 + i.days).iso8601
        sint1.service_instance.upsert_webhook(body: {"my_id" => i.to_s, "at" => t})
        sint2.service_instance.upsert_webhook(body: {"my_id" => i.to_s, "at" => t})
      end
      dbinfo = Webhookdb::Organization::DbBuilder.new(org).prepare_database_connections
      @dbmigration = described_class.enqueue(
        admin_connection_url_raw: dbinfo.admin_url,
        readonly_connection_url_raw: dbinfo.readonly_url,
        public_host: org.public_host,
        started_by: nil,
        organization: org,
      )
    end

    after(:each) do
      org.remove_related_database
    end

    it "does not set started at if already set" do
      t = 3.hours.ago
      dbmigration.update(started_at: t)
      dbmigration.migrate
      expect(dbmigration).to have_attributes(started_at: t, finished_at: be_within(5).of(Time.now))
    end

    it "errors if already finished" do
      dbmigration.update(finished_at: Time.now)
      expect { dbmigration.migrate }.to raise_error(described_class::MigrationAlreadyFinished)
    end

    it "inserts data from the old connection tables into new connection tables" do
      started = Time.now
      sint1.service_instance.create_table
      expect(sint1.service_instance.readonly_dataset(&:all)).to be_empty
      dbmigration.migrate
      expect(dbmigration).to have_attributes(
        started_at: be_within(2).of(started),
        finished_at: be_within(10).of(Time.now),
        last_migrated_service_integration_id: sint_no_table.id,
        last_migrated_timestamp: be_nil,
      )
      expect(dbmigration.refresh).to have_attributes(finished_at: be_present)
      expect(sint1.service_instance.readonly_dataset(&:all)).to have_length(52)
    end

    it "does not overwrite newer rows in the desetination database (conditional upsert)" do
      sint1.service_instance.create_table
      body = {"my_id" => "5", "at" => (t0 + 100.days).iso8601, "extra" => 1}
      sint1.service_instance.upsert_webhook(body:)
      dbmigration.migrate
      expect(sint1.service_instance.readonly_dataset(&:all)).to have_length(52)
      expect(sint1.service_instance.readonly_dataset { |ds| ds[my_id: "5"] }[:data]).to eq(body)
    end

    it "keeps track of table and row progress", :async, :do_not_defer_events do
      expect do
        dbmigration.migrate
      end.to publish("webhookdb.organization.databasemigration.updated").with_payload(
        contain_exactly(
          dbmigration.id,
          include("last_migrated_timestamp" => [nil, match_time("2015-01-10 00:00:00 +0000")]),
        ),
      ).and("webhookdb.organization.databasemigration.updated").with_payload(
        contain_exactly(
          dbmigration.id,
          include(
            "last_migrated_timestamp" => [
              match_time("2015-01-10 00:00:00 +0000"), match_time("2015-01-20 00:00:00 +0000"),
            ],
          ),
        ),
      ).and("webhookdb.organization.databasemigration.updated").with_payload(
        contain_exactly(
          dbmigration.id,
          include("last_migrated_service_integration_id" => [0, sint1.id]),
        ),
      )
    end

    it "can resume where it left off" do
      sint1.service_instance.create_table # Skipped so need to do this manually
      dbmigration.update(last_migrated_service_integration_id: sint1.id, last_migrated_timestamp: t0 + 30.days)
      dbmigration.migrate
      # Should have been skipped due to setting last migrated integration
      expect(sint1.service_instance.readonly_dataset(&:all)).to be_empty
      # Should be shorter due to setting last migrated timestamp
      expect(sint2.service_instance.readonly_dataset(&:all)).to have_length(21)
    end
  end

  describe "finish" do
    it "marks the migration finished and clears fields" do
      org = Webhookdb::Fixtures.organization.create(
        admin_connection_url_raw: "postgres://admin:p@oldhost/db",
        readonly_connection_url_raw: "postgres://ro:p@oldhost/db",
      )
      dbm = described_class.enqueue(
        admin_connection_url_raw: org.admin_connection_url_raw,
        readonly_connection_url_raw: org.readonly_connection_url_raw,
        public_host: "",
        started_by: nil,
        organization: org,
      )
      dbm.finish
      expect(dbm).to have_attributes(
        finished_at: be_within(5).of(Time.now),
        source_admin_connection_url: "",
        destination_admin_connection_url: "",
      )
    end
  end

  describe "guard_ongoing!" do
    let(:org) { Webhookdb::Fixtures.organization.create }

    it "errors if there is on ongoing migration" do
      Webhookdb::Fixtures.organization_database_migration(organization: org).create
      expect { described_class.guard_ongoing!(org) }.to raise_error(described_class::MigrationInProgress)
    end

    it "passes if there is no ongoing migration" do
      expect { described_class.guard_ongoing!(org) }.to_not raise_error
    end
  end

  describe "validations" do
    it "can only have one in-progress migration for an organization at a time" do
      organization = Webhookdb::Fixtures.organization.create
      dbmfac = Webhookdb::Fixtures.organization_database_migration(organization:)
      dbm1_init = dbmfac.create
      dbm1_finished = dbmfac.finished.create
      dbm2_started = Webhookdb::Fixtures.organization_database_migration.create

      expect do
        dbmfac.started.create
      end.to raise_error(Sequel::UniqueConstraintViolation)
    end
  end
end
