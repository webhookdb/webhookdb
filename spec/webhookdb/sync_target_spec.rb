# frozen_string_literal: true

RSpec.describe "Webhookdb::SyncTarget", :db do
  let(:described_class) { Webhookdb::SyncTarget }
  let(:sint) { Webhookdb::Fixtures.service_integration.create }

  describe "association" do
    it "returns its associated type and id" do
      st = Webhookdb::Fixtures.sync_target(service_integration: sint).create
      expect(st).to have_attributes(
        associated_type: "service_integration",
        associated_id: sint.opaque_id,
      )
    end
  end

  describe "datasets" do
    it "can find instances due for sync" do
      fac = Webhookdb::Fixtures.sync_target(period_seconds: 60)
      never_run = fac.create
      run_ago = fac.create(last_synced_at: 2.minutes.ago)
      run_recently = fac.create(last_synced_at: 30.seconds.ago)
      found = described_class.due_for_sync(as_of: Time.now).all
      expect(found).to have_same_ids_as(never_run, run_ago)
    end
  end

  describe "displaysafe_connection_url" do
    it "obfuscates username and password" do
      st = Webhookdb::Fixtures.sync_target(connection_url: "postgres://foo:password@host:123/dbname").create
      expect(st).to have_attributes(displaysafe_connection_url: "postgres://***:***@host:123/dbname")
    end
  end

  describe "next_possible_sync" do
    let(:stgt) { Webhookdb::Fixtures.sync_target.create(period_seconds: 500) }
    let(:now) { trunc_time(Time.now) }
    let(:min_period) { 60 }

    around(:each) do |example|
      described_class.min_period_seconds = min_period
      Timecop.freeze do
        example.run
      end
      described_class.reset_configuration
    end

    it "returns now if the sync has not run" do
      expect(stgt.next_possible_sync(now:)).to eq(now)
    end

    it "returns now if the last run was more than min sync period ago" do
      stgt.last_synced_at = 61.seconds.ago
      expect(stgt.next_possible_sync(now:)).to eq(now)
    end

    it "returns the last sync time plus min sync period if last run was less than min sync period ago" do
      stgt.last_synced_at = 32.seconds.ago
      expect(stgt.next_possible_sync(now:)).to eq(28.seconds.from_now)
    end
  end

  describe "next_scheduled_sync" do
    let(:stgt) { Webhookdb::Fixtures.sync_target.create(period_seconds: 60) }
    let(:now) { trunc_time(Time.now) }

    around(:each) do |example|
      Timecop.freeze do
        example.run
      end
    end

    it "returns now if the sync has not run" do
      expect(stgt.next_scheduled_sync(now:)).to eq(now)
    end

    it "returns now if the last run was more than target's sync period ago" do
      stgt.last_synced_at = 61.seconds.ago
      expect(stgt.next_scheduled_sync(now:)).to eq(now)
    end

    it "returns the last sync time plus min sync period if last run was less than the target's sync period ago" do
      stgt.last_synced_at = 33.seconds.ago
      expect(stgt.next_scheduled_sync(now:)).to eq(27.seconds.from_now)
    end
  end

  describe "run_sync" do
    before(:each) do
      sint.organization.prepare_database_connections
      sint.service_instance.create_table
      sint.service_instance.upsert_webhook(body: {"my_id" => "abc", "at" => "Thu, 30 Jul 2016 21:12:33 +0000"})
      sint.service_instance.upsert_webhook(body: {"my_id" => "def", "at" => "Thu, 30 Jul 2017 21:12:33 +0000"})
      sint.service_instance.upsert_webhook(body: {"my_id" => "ghi", "at" => "Thu, 30 Jul 2018 21:12:33 +0000"})
    end

    after(:each) do
      sint.organization.remove_related_database
      Webhookdb::ServiceIntegration.drop_schema!(:whdbsynctest)
    end

    it "aborts if the row is already locked", db: :no_transaction do
      sync_tgt = Webhookdb::Fixtures.sync_target(service_integration: sint).create
      Sequel.connect(Webhookdb::Postgres::Model.uri) do |otherconn|
        otherconn.transaction(rollback: :always) do
          otherconn[:sync_targets].where(id: sync_tgt.id).lock_style("FOR UPDATE").update(last_synced_at: Time.now)
          expect do
            sync_tgt.run_sync(at: Time.parse("Thu, 30 Aug 2017 21:12:33 +0000"))
          end.to raise_error(Webhookdb::SyncTarget::SyncInProgress)
        end
      end
    end

    describe "with a postgres target" do
      let(:sync_tgt) { Webhookdb::Fixtures.sync_target(service_integration: sint).postgres.create }

      it "incrementally syncs to PG and sets last synced" do
        t1 = Time.parse("Thu, 30 Aug 2017 21:12:33 +0000")
        sync_tgt.run_sync(at: t1)
        expect(sync_tgt.connect_target_db[Sequel[:whdbsynctest][sint.table_name.to_sym]].all).to have_length(2)
        expect(sync_tgt).to have_attributes(last_synced_at: match_time(t1))

        t2 = Time.parse("Thu, 30 Aug 2020 21:12:33 +0000")
        sync_tgt.run_sync(at: t2)
        expect(sync_tgt.connect_target_db[Sequel[:whdbsynctest][sint.table_name.to_sym]].all).to have_length(3)
        expect(sync_tgt).to have_attributes(last_synced_at: match_time(t2))
      end

      it "can use an explicit schema and table" do
        Webhookdb::ServiceIntegration.drop_schema!(:whdbsynctest)
        sync_tgt.update(schema: "synctgttestschema", table: "synctgttesttable")
        sync_tgt.run_sync(at: Time.parse("Thu, 30 Aug 2020 21:12:33 +0000"))
        expect(sync_tgt.db[Sequel[:synctgttestschema][:synctgttesttable]].all).to have_length(3)
      ensure
        Webhookdb::ServiceIntegration.drop_schema!(:whdbsynctest)
      end
    end
  end
end
