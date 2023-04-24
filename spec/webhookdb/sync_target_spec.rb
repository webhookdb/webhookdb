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

  describe "schema_and_table_string" do
    it "displays" do
      described_class.default_schema = "defaultschema"
      st = Webhookdb::Fixtures.sync_target(service_integration: sint).create
      sint.table_name = "xyz"
      expect(st.schema_and_table_string).to eq("defaultschema.xyz")
      st.schema = "foo"
      expect(st.schema_and_table_string).to eq("foo.xyz")
      st.table = "bar"
      expect(st.schema_and_table_string).to eq("foo.bar")
    ensure
      described_class.reset_configuration
    end
  end

  describe "associated_object_display" do
    it "displays service integrations" do
      sint.update(table_name: "mytable", opaque_id: "svi_myid")
      st = Webhookdb::Fixtures.sync_target(service_integration: sint).create
      expect(st.associated_object_display).to eq("svi_myid/mytable")
    end
  end

  describe "next_possible_sync" do
    let(:stgt) { Webhookdb::Fixtures.sync_target.create(period_seconds: 500) }
    let(:now) { trunc_time(Time.now) }
    let(:min_period) { 60 }

    around(:each) do |example|
      described_class.default_min_period_seconds = min_period
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

  describe "validate_db_url" do
    it "returns nil if the url is for a supported database" do
      expect(described_class.validate_db_url("postgres://u:p@x:5432/db")).to be_nil
    end

    it "returns an error if the url is https" do
      expect(described_class.validate_db_url("https://u:p@x/db")).to match(
        /'https' protocol is not supported for database sync targets\. Supported protocols are: postgres, snowflake\./,
      )
    end

    it "returns an error if the url is http" do
      Webhookdb::SyncTarget.allow_http = true
      expect(described_class.validate_db_url("http://u:p@x/db")).to match(
        /'http' protocol is not supported for database sync targets\. Supported protocols are: postgres, snowflake\./,
      )
    end

    it "returns an error if the url cannot be parsed" do
      expect(described_class.validate_db_url("this is not ao url")).to eq("That's not a valid URL.")
    end

    it "returns an error if the database is not supported" do
      expect(described_class.validate_db_url("oracle://u:p@x:5432/db")).to eq(
        # rubocop:disable Layout/LineLength
        "The 'oracle' protocol is not supported for database sync targets. Supported protocols are: postgres, snowflake.",
        # rubocop:enable Layout/LineLength
      )
    end
  end

  describe "validate_http_url" do
    it "returns nil if the url is https" do
      expect(described_class.validate_http_url("https://u:p@x/db")).to be_nil
      expect(described_class.validate_http_url("https://:p@x/db")).to be_nil
      expect(described_class.validate_http_url("https://u@x/db")).to be_nil
    end

    it "returns nil if the url is http and config allows http urls" do
      Webhookdb::SyncTarget.allow_http = true
      expect(described_class.validate_http_url("http://u:p@x/db")).to be_nil
      expect(described_class.validate_http_url("http://:p@x/db")).to be_nil
      expect(described_class.validate_http_url("http://u@x/db")).to be_nil
    end

    it "returns an error if the url is for a database" do
      expect(described_class.validate_http_url("postgres://u:p@x:5432/db")).to eq(
        "Must be an https url.",
      )
    end

    it "returns an error if the url cannot be parsed" do
      expect(described_class.validate_http_url("this is not ao url")).to eq(
        "That's not a valid URL.",
      )
    end

    it "returns an error if the url is http and config disallows http urls" do
      Webhookdb::SyncTarget.allow_http = false
      expect(described_class.validate_http_url("http://u:p@x:5432/db")).to eq(
        "Url must be https, not http.",
      )
    end

    it "returns an error if the https url has no username or password" do
      expect(described_class.validate_http_url("https://x/handler")).to eq(
        "https urls must include a Basic Auth username and/or password, like 'https://user:pass@x/handler'",
      )
    end
  end

  describe "verify_db_connection" do
    describe "postgres" do
      it "verifies that postgres connection is valid" do
        expect do
          described_class.verify_db_connection(Webhookdb::Postgres::Model.uri)
        end.to_not raise_error
      end

      it "raises error if postgres connection is invalid" do
        expect do
          described_class.verify_db_connection("postgres://u:p@x.y")
        end.to raise_error(described_class::InvalidConnection, /Could not SELECT 1/)
      end

      it "raises an error if the postgres connection times out" do
        stub_const("Webhookdb::SyncTarget::DB_VERIFY_TIMEOUT", 0.001)
        stub_const("Webhookdb::SyncTarget::DB_VERIFY_STATEMENT", "SELECT generate_series(0, 100000")
        expect do
          described_class.verify_db_connection("postgres://u:p@x.y")
        end.to raise_error(described_class::InvalidConnection, start_with("Could not SELECT 1: could not "))
      end
    end
  end

  describe "verify_http_connection" do
    it "verifies that http connection is valid" do
      req = stub_request(:post, "https://a.b/").
        with(
          body: {
            rows: [],
            integration_id: "svi_test",
            integration_service: "httpsync_test",
            table: "test",
          },
        ).to_return(status: 200, body: "", headers: {})

      expect do
        described_class.verify_http_connection("https://u:p@a.b")
      end.to_not raise_error
      expect(req).to have_been_made
    end

    it "raises error if http connection is invalid" do
      req = stub_request(:post, "https://a.b/").
        to_return(status: 403, body: "", headers: {})

      expect do
        described_class.verify_http_connection("https://u:p@a.b")
      end.to raise_error(
        described_class::InvalidConnection,
        include("POST to https://a.b failed: HttpError(status: 403"),
      )
      expect(req).to have_been_made
    end

    it "raises error if http times out" do
      req = stub_request(:post, "https://a.b/").to_timeout

      expect do
        described_class.verify_http_connection("https://u:p@a.b")
      end.to raise_error(
        described_class::InvalidConnection,
        include("POST to https://a.b timed out: execution expired"),
      )
      expect(req).to have_been_made
    end
  end

  describe "run_sync" do
    before(:each) do
      sint.organization.prepare_database_connections
      sint.replicator.create_table
      sint.replicator.upsert_webhook_body({"my_id" => "abc", "at" => "Thu, 30 Jul 2016 21:12:33 +0000"})
      sint.replicator.upsert_webhook_body({"my_id" => "def", "at" => "Thu, 30 Jul 2017 21:12:33 +0000"})
      sint.replicator.upsert_webhook_body({"my_id" => "ghi", "at" => "Thu, 30 Jul 2018 21:12:33 +0000"})
    end

    before(:all) do
      @default_schema = Webhookdb::SyncTarget.default_schema.to_sym
      raise "Custom test schema must have been set!" if @default_schema == :public
      @custom_schema = :synctgttestschema
    end

    after(:each) do
      sint.organization.remove_related_database
    end

    it "aborts if a sync is already in progress" do
      sync_tgt = Webhookdb::Fixtures.sync_target(service_integration: sint).create
      Sequel.connect(Webhookdb::Postgres::Model.uri) do |otherconn|
        Sequel::AdvisoryLock.new(otherconn, described_class::ADVISORY_LOCK_KEYSPACE, sync_tgt.id).with_lock do
          expect do
            sync_tgt.run_sync(now: Time.parse("Thu, 30 Aug 2017 21:12:33 +0000"))
          end.to raise_error(Webhookdb::SyncTarget::SyncInProgress)
        end
      end
    end

    it "releases the lock after sync" do
      sync_tgt = Webhookdb::Fixtures.sync_target(service_integration: sint).create
      expect(sync_tgt.db[:pg_locks].where(classid: described_class::ADVISORY_LOCK_KEYSPACE).all).to be_empty
      sync_tgt.run_sync(now: Time.parse("Thu, 30 Aug 2017 21:12:33 +0000"))
      expect(sync_tgt.db[:pg_locks].where(classid: described_class::ADVISORY_LOCK_KEYSPACE).all).to be_empty
    end

    it "releases the lock after sync if there is an error" do
      sync_tgt = Webhookdb::Fixtures.sync_target(service_integration: sint).create
      expect(sync_tgt.db[:pg_locks].where(classid: described_class::ADVISORY_LOCK_KEYSPACE).all).to be_empty
      expect(described_class::DatabaseRoutine).to receive(:new).and_raise(RuntimeError)
      expect do
        sync_tgt.run_sync(now: Time.parse("Thu, 30 Aug 2017 21:12:33 +0000"))
      end.to raise_error(RuntimeError)
      expect(sync_tgt.db[:pg_locks].where(classid: described_class::ADVISORY_LOCK_KEYSPACE).all).to be_empty
    end

    describe "with a postgres target" do
      let(:sync_tgt) { Webhookdb::Fixtures.sync_target(service_integration: sint).postgres.create }
      let(:adapter_conn) { Webhookdb::DBAdapter.adapter(sync_tgt.connection_url).connection(sync_tgt.connection_url) }

      before(:each) do
        drop_schemas
      end

      after(:each) do
        drop_schemas
      end

      def drop_schemas
        Sequel.connect(Webhookdb::Postgres::Model.uri) do |db|
          [@default_schema, @custom_schema].each do |sch|
            db.drop_schema(sch, if_exists: true, cascade: true)
          end
        end
      end

      it "incrementally syncs to PG and sets last synced" do
        t1 = Time.parse("Thu, 30 Aug 2017 21:12:33 +0000")
        sync_tgt.run_sync(now: t1)
        adapter_conn.using do |db|
          expect(db[Sequel[@default_schema][sint.table_name.to_sym]].all).to have_length(2)
        end
        expect(sync_tgt).to have_attributes(last_synced_at: match_time(t1))

        t2 = Time.parse("Thu, 30 Aug 2020 21:12:33 +0000")
        sync_tgt.run_sync(now: t2)
        adapter_conn.using do |db|
          expect(db[Sequel[@default_schema][sint.table_name.to_sym]].all).to have_length(3)
        end
        expect(sync_tgt).to have_attributes(last_synced_at: match_time(t2))
      end

      it "can use an explicit schema and table" do
        sync_tgt.update(schema: @custom_schema.to_s, table: "synctgttesttable")
        sync_tgt.run_sync(now: Time.parse("Thu, 30 Aug 2020 21:12:33 +0000"))
        adapter_conn.using do |db|
          expect(db[Sequel[@custom_schema][:synctgttesttable]].all).to have_length(3)
        end
      end

      describe "schema caching" do
        it "executes schema changes if they change between syncs" do
          logs = capture_logs_from(Webhookdb.logger) do
            sync_tgt.run_sync(now: 2.hours.ago)
            expect(sync_tgt.last_applied_schema).to include("CREATE SCHEMA")
            sync_tgt.run_sync(now: 1.hour.ago)
            sync_tgt.update(last_applied_schema: sync_tgt.last_applied_schema + ";")
            sync_tgt.run_sync(now: Time.now)
          end
          schema_logs = logs.select { |line| line.to_s.include?("CREATE SCHEMA") }
          expect(schema_logs).to have_length(2)
        end
      end
    end

    describe "with a snowflake target" do
      break unless Webhookdb::Snowflake.run_tests

      let(:sync_tgt) { Webhookdb::Fixtures.sync_target(service_integration: sint).snowflake.create }

      before(:all) do
        drop_schemas
      end

      after(:all) do
        drop_schemas
      end

      def drop_schemas
        run_cli("DROP SCHEMA IF EXISTS #{@default_schema} CASCADE; " \
                "DROP SCHEMA IF EXISTS #{@custom_schema} CASCADE;")
      end

      def run_cli(cmd)
        return Webhookdb::Snowflake.run_cli(Webhookdb::Snowflake.test_url, cmd, parse: true)
      end

      it "incrementally syncs to Snowflake and sets last synced" do
        t1 = Time.parse("Thu, 30 Aug 2017 21:12:33 +0000")
        sync_tgt.run_sync(now: t1)
        values = run_cli("SELECT pk, my_id, at, data FROM #{@default_schema}.#{sint.table_name}")
        expect(values.flatten).to have_length(2)
        expect(sync_tgt).to have_attributes(last_synced_at: match_time(t1))

        t2 = Time.parse("Thu, 30 Aug 2020 21:12:33 +0000")
        sync_tgt.run_sync(now: t2)
        values = run_cli("SELECT pk, my_id, at, data FROM #{@default_schema}.#{sint.table_name}")
        expect(values.flatten).to have_length(3)
        expect(sync_tgt).to have_attributes(last_synced_at: match_time(t2))
      end

      it "can use an explicit schema and table" do
        sync_tgt.update(schema: "synctgttestschema", table: "synctgttesttable")
        sync_tgt.run_sync(now: Time.parse("Thu, 30 Aug 2020 21:12:33 +0000"))
        values = run_cli("SELECT pk, my_id, at, data FROM #{@custom_schema}.synctgttesttable")
        expect(values.flatten).to have_length(3)
      end

      describe "schema caching" do
        it "is not tested explicitly because Snowflake is slow"
        # We can add it if we find it behaves differently
      end
    end

    describe "with an https target" do
      url = "https://user:pass@sync-target-webhook/xyz"
      let(:sync_tgt) { Webhookdb::Fixtures.sync_target(service_integration: sint).https(url).create }

      it "incrementally POSTs to the webhook and sets last synced" do
        t1 = Time.parse("Thu, 30 Aug 2017 21:12:33 +0000")
        sync1_req = stub_request(:post, "https://sync-target-webhook/xyz").
          with(
            body: {
              rows: [
                {
                  pk: 1,
                  my_id: "abc",
                  at: "2016-07-30T21:12:33.000+00:00",
                  data: {at: "Thu, 30 Jul 2016 21:12:33 +0000", my_id: "abc"},
                },
                {
                  pk: 2,
                  my_id: "def",
                  at: "2017-07-30T21:12:33.000+00:00",
                  data: {at: "Thu, 30 Jul 2017 21:12:33 +0000", my_id: "def"},
                },
              ],
              integration_id: sint.opaque_id,
              integration_service: "fake_v1",
              table: sint.table_name,
              sync_timestamp: t1,
            },
          ).
          to_return(status: 200, body: "", headers: {})

        sync_tgt.run_sync(now: t1)
        expect(sync_tgt).to have_attributes(last_synced_at: match_time(t1))
        expect(sync1_req).to have_been_made

        t2 = Time.parse("Thu, 30 Aug 2020 21:12:33 +0000")
        sync2_req = stub_request(:post, "https://sync-target-webhook/xyz").
          with(
            body: {
              rows: [
                {
                  pk: 3,
                  my_id: "ghi",
                  at: "2018-07-30T21:12:33.000+00:00",
                  data: {at: "Thu, 30 Jul 2018 21:12:33 +0000", my_id: "ghi"},
                },
              ],
              integration_id: sint.opaque_id,
              integration_service: "fake_v1",
              table: sint.table_name,
              sync_timestamp: t2,
            },
          ).
          to_return(status: 200, body: "", headers: {})
        sync_tgt.run_sync(now: t2)
        expect(sync_tgt).to have_attributes(last_synced_at: match_time(t2))
        expect(sync2_req).to have_been_made
      end

      it "records timestamp of last successful synced item, logs, and ignores http errors" do
        sync_tgt.update(page_size: 2)
        reqs = stub_request(:post, "https://sync-target-webhook/xyz").
          to_return({status: 200, body: "", headers: {}}).
          to_return(status: 413, body: "body too large", headers: {})
        sync_tgt.run_sync(now: Time.now)
        expect(reqs).to have_been_made.times(2)
        expect(sync_tgt).to have_attributes(last_synced_at: match_time("Thu, 30 Jul 2017 21:12:33 +0000"))
      end

      it "records timestamp of last successful synced item and raises if a non-http error occurs" do
        sync_tgt.update(page_size: 2)
        rte = RuntimeError.new("hi")
        req = stub_request(:post, "https://sync-target-webhook/xyz").
          to_return(status: 200, body: "", headers: {}).
          to_raise(rte)
        expect do
          sync_tgt.run_sync(now: Time.now)
        end.to raise_error(rte)
        expect(req).to have_been_made.times(2)
        expect(sync_tgt).to have_attributes(last_synced_at: match_time("Thu, 30 Jul 2017 21:12:33 +0000"))
      end
    end
  end
end
