# frozen_string_literal: true

RSpec.describe "Webhookdb::SyncTarget", :db, reset_configuration: Webhookdb::SyncTarget do
  let(:described_class) { Webhookdb::SyncTarget }
  let(:sint) { Webhookdb::Fixtures.service_integration.create }

  transport_errors = [
    # These errors happen when DNS can't resolve, but the error isn't consistent.
    SocketError.new(
      "Failed to open TCP connection to a.b.zyxw:443 (getaddrinfo: nodename nor servname provided, or not known",
    ),
    Class.new(StandardError) do
      def self.name = "Socket::ResolutionError"
      def error_code = "123"
    end.new("Failed to open TCP connection to a.b.zyxw:443 (getaddrinfo: Name or service not known)"),
    Errno::ENETUNREACH.new("Failed to open TCP connection to a.b.zyxw:443 (getaddrinfo: blah)"),
    # This is a really common transport error, sort of like an http timeout but not raised by http
    Errno::ECONNRESET.new("Connection reset", 2),
  ]

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

  describe "sync_stats" do
    let(:syt) { Webhookdb::Fixtures.sync_target.create(page_size: 100) }

    def add_sync_stat(t, **kw) = syt.add_sync_stat(call_start: t, remote_start: t, **kw)

    it "can summarize stats" do
      expect(syt.sync_stat_summary).to eq({})
      Timecop.freeze("2024-10-21T13:27:29Z") do
        add_sync_stat(12.seconds.ago)
        add_sync_stat(9.seconds.ago, response_status: 503)
        add_sync_stat(6.seconds.ago, exception: RuntimeError.new("hi"))
        add_sync_stat(3.seconds.ago, remote_start: 1.second.ago)
        expect(syt.sync_stat_summary).to include(
          avg_call_latency: 7.5,
          avg_remote_latency: 7.0,
          errors: 2,
        )
      end
    end

    it "includes calls per minute" do
      Timecop.freeze("2024-10-10T00:00:00Z") do
        Timecop.freeze(30.seconds.ago) { add_sync_stat(Time.now) }
        expect(syt.sync_stat_summary).to include(avg_calls_minute: 2, avg_rows_minute: 200)
        Timecop.freeze(30.seconds.ago) { add_sync_stat(Time.now) }
        expect(syt.sync_stat_summary).to include(avg_calls_minute: 4)
        Timecop.freeze(30.seconds.ago) { add_sync_stat(Time.now) }
        expect(syt.sync_stat_summary).to include(avg_calls_minute: 6)
      end
    end

    it "includes earliest and latest calls" do
      Timecop.freeze("2024-10-10T00:00:00Z") do
        Timecop.freeze(12.seconds.ago) { add_sync_stat(Time.now) }
        Timecop.freeze(3.seconds.ago) { add_sync_stat(Time.now) }
        expect(syt.sync_stat_summary).to include(
          earliest: match_time(12.seconds.ago),
          latest: match_time(3.seconds.ago),
        )
      end
    end

    it "ignores missing keys" do
      syt.sync_stats = [{"x" => 1}, {"t" => 5}]
      expect(syt.sync_stat_summary).to include(
        avg_remote_latency: 0,
        avg_call_latency: 0,
        avg_rows_minute: 0,
        earliest: match_time(0),
        errors: 0,
        latest: match_time(0),
      )
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

  describe "jitter" do
    before(:each) do
      r = Random.new(5)
      stub_const("Webhookdb::SyncTarget::RAND", r)
    end

    it "chooses a random value between 1 and 20 seconds" do
      stgt = Webhookdb::Fixtures.sync_target(period_seconds: 600).instance
      expect(stgt.jitter).to eq(4)
      expect(stgt.jitter).to eq(15)
    end

    it "nevers use a jitter greater than 1/4 of the period" do
      stgt = Webhookdb::Fixtures.sync_target(period_seconds: 0).instance
      expect(stgt.jitter).to eq(1)
      stgt.period_seconds = 1
      expect(stgt.jitter).to eq(1)
      stgt.period_seconds = 4
      20.times { expect(stgt.jitter).to eq(1) }
      stgt.period_seconds = 20
      expect(stgt.jitter).to eq(4)
      40.times { expect(stgt.jitter).to be <= 5 }
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

    it "raises invalid connection on http error" do
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

    it "raises invalid connection on http timeout" do
      req = stub_request(:post, "https://a.b/").to_timeout

      expect do
        described_class.verify_http_connection("https://u:p@a.b")
      end.to raise_error(
        described_class::InvalidConnection,
        include("POST to https://a.b failed: execution expired"),
      )
      expect(req).to have_been_made
    end

    transport_errors.each do |e|
      it "raises invalid connection for transport errors (#{e.class.name})" do
        # To make sure this works as expected, you can allow_net_connect and comment out the request stubs.
        # Socket errors are raised much lower down than webmock, so we can't use normal rspec stubs.
        # WebMock.allow_net_connect!
        req = stub_request(:post, "https://a.b.zyxw").and_raise(e)
        expect do
          described_class.verify_http_connection("https://a.b.zyxw")
        end.to raise_error(described_class::InvalidConnection, include("POST to https://a.b.zyxw failed: "))
        expect(req).to have_been_made
      end
    end

    it "reraises unhandled errors" do
      err = ArgumentError.new("hello")
      req = stub_request(:post, "https://a.b/").and_raise(err)

      expect do
        described_class.verify_http_connection("https://u:p@a.b")
      end.to raise_error(err)
      expect(req).to have_been_made
    end
  end

  describe "latency" do
    it "returns the duration between now and the last sync" do
      Timecop.freeze do
        syt = Webhookdb::Fixtures.sync_target.create(last_synced_at: Time.now - 35.seconds)
        expect(syt).to have_attributes(latency: be_within(0.1).of(35.seconds))
      end
    end

    it "uses 0 for a future or missing last sync time" do
      syt = Webhookdb::Fixtures.sync_target.create(last_synced_at: nil)
      expect(syt).to have_attributes(latency: 0)
      syt.last_synced_at = 10.minutes.from_now
      expect(syt).to have_attributes(latency: 0)
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

    it "noops if disabled" do
      sync_tgt = Webhookdb::Fixtures.sync_target.create(disabled: true)
      expect(sync_tgt.run_sync(now: Time.now)).to be(false)
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

    shared_examples_for "an https sync target" do |**params|
      url = "https://user:pass@sync-target-webhook/xyz"
      let(:sync_tgt) { Webhookdb::Fixtures.sync_target(service_integration: sint).https(url).create(**params) }

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
        expect(sync_tgt.refresh.sync_stats.to_a).to contain_exactly(
          hash_including("dr", "t"),
          hash_including("dr", "t"),
        )
      end

      it "records timestamp of last successful synced item, logs, and ignores http errors" do
        sync_tgt.update(page_size: 2)
        reqs = stub_request(:post, "https://sync-target-webhook/xyz").
          to_return({status: 200, body: "", headers: {}}).
          to_return(status: 413, body: "body too large", headers: {})
        sync_tgt.run_sync(now: Time.now)
        expect(reqs).to have_been_made.times(2)
        expect(sync_tgt).to have_attributes(last_synced_at: match_time("Thu, 30 Jul 2017 21:12:33 +0000"))
        expect(sync_tgt.refresh.sync_stats.to_a).to contain_exactly(
          hash_including("dr", "t"),
          hash_including("dr", "t", "rs" => 413),
        )
      end

      transport_errors.each do |e|
        it "logs and does not reraise transport errors (#{e.class.name})" do
          sync_tgt.update(page_size: 2)
          reqs = stub_request(:post, "https://sync-target-webhook/xyz").and_raise(e)
          sync_tgt.run_sync(now: Time.now)
          expect(reqs).to have_been_made
          expect(sync_tgt).to have_attributes(last_synced_at: be_nil)
        end
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

      it "raises a Deleted error if the sync target is destroyed during the sync" do
        req = stub_request(:post, "https://sync-target-webhook/xyz").
          to_return do
          # Destroy this while the sync is running
          Webhookdb::SyncTarget[sync_tgt.id]&.destroy
          {status: 200, body: "", headers: {}}
        end
        expect { sync_tgt.run_sync(now: Time.now) }.to raise_error(Webhookdb::SyncTarget::Deleted)
        expect(req).to have_been_made
      end

      it "records only up to MAX_STATS" do
        stub_const("Webhookdb::SyncTarget::MAX_STATS", 13)
        sync_tgt.update(page_size: 1)
        Array.new(20) do |i|
          sint.replicator.upsert_webhook_body({"my_id" => "a-#{i}", "at" => "Thu, 30 Jul 2016 21:12:33 +0000"})
        end
        req = stub_request(:post, "https://sync-target-webhook/xyz").
          to_return(status: 200, body: "", headers: {})
        sync_tgt.run_sync(now: Time.now)
        expect(req).to have_been_made.times(23) # new rows, plus the 3 original
        expect(sync_tgt.refresh.sync_stats).to have_length(13)
      end

      describe "when the max transaction timeout is reached" do
        before(:each) do
          described_class.max_transaction_seconds = 0
          sync_tgt.update(page_size: 1)
        end

        final_synced_row_ts = Time.parse("Thu, 30 Jul 2016 21:12:33 +0000")
        now = Time.parse("Thu, 30 Aug 2017 21:12:33 +0000")

        it "has no special behavior if not already in a job" do
          Thread.current[:sidekiq_context] = nil
          sync1_req = stub_request(:post, "https://sync-target-webhook/xyz").
            to_return(status: 200, body: "", headers: {})
          expect(Webhookdb::Jobs::SyncTargetRunSync).to_not receive(:perform_async)

          sync_tgt.run_sync(now:)
          expect(sync_tgt).to have_attributes(last_synced_at: match_time(now))
          expect(sync1_req).to have_been_made.times(2)
        end

        it "stops and reschedules itself if there is a sidekiq context" do
          Thread.current[:sidekiq_context] = {}
          sync1_req = stub_request(:post, "https://sync-target-webhook/xyz").
            to_return(status: 200, body: "", headers: {})
          expect(Webhookdb::Jobs::SyncTargetRunSync).to receive(:perform_async).with(sync_tgt.id)

          sync_tgt.run_sync(now:)
          # Last synced should be the row timestamp, not 'now', since we stopped early.
          expect(sync_tgt).to have_attributes(last_synced_at: match_time(final_synced_row_ts))
          expect(sync1_req).to have_been_made
        ensure
          Thread.current[:sidekiq_context] = nil
        end
      end
    end

    describe "with a single threaded https target" do
      it_behaves_like "an https sync target"
    end

    describe "with a multi-threaded https sync target", db: :no_transaction do
      it_behaves_like "an https sync target", {parallelism: 3}
    end
  end
end
