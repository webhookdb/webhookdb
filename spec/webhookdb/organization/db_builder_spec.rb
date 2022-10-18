# frozen_string_literal: true

# rubocop:disable Layout/LineLength
RSpec.describe Webhookdb::Organization::DbBuilder, :db, whdbisolation: :reset do
  let(:this_dbserver_url) { described_class.available_server_urls.first }

  describe "configuration", whdbisolation: true do
    it "errors if there isolation mode is empty" do
      described_class.isolation_mode = ""
      expect { described_class.run_after_configured_hooks }.to raise_error(KeyError)
    end

    it "errors for invalid isolation modes" do
      described_class.isolation_mode = "database foo"
      expect { described_class.run_after_configured_hooks }.to raise_error(KeyError)
    end

    it "sets a valid isolation mode" do
      described_class.isolation_mode = "database+user"
      expect { described_class.run_after_configured_hooks }.to_not raise_error
    end
  end

  describe "prepare_database_connections" do
    let!(:o) { Webhookdb::Fixtures.organization.create(name: "Unit Test") }

    it "errors if there are already database connections on the object" do
      assign_connection_urls(o)
      expect do
        o.prepare_database_connections
      end.to raise_error(Webhookdb::InvalidPrecondition, "connections already set")
    end

    describe "using database+user isolation", whdbisolation: "database+user" do
      it "creates a randomly named database and connection strings and the public schema" do
        o.prepare_database_connections
        expect(o).to have_attributes(
          admin_connection_url: %r(postgres://aad#{o.id}a[0-9a-f]{16}:a#{o.id}a[0-9a-f]{16}@localhost:18006/adb#{o.id}a[0-9a-f]{16}),
          readonly_connection_url: %r(postgres://aro#{o.id}a[0-9a-f]{16}:a#{o.id}a[0-9a-f]{16}@localhost:18006/adb#{o.id}a[0-9a-f]{16}),
          replication_schema: "public",
        )
      end

      it "scopes the admin connection permissions" do
        o.prepare_database_connections
        Sequel.connect(o.admin_connection_url) do |admin_conn|
          admin_conn << "CREATE TABLE my_test_table(val TEXT)"
          admin_conn << "INSERT INTO my_test_table (val) VALUES ('x')"
          rows = admin_conn.fetch("SELECT * FROM my_test_table").all
          expect(rows).to(eq([{val: "x"}]))
          admin_conn << "DROP TABLE my_test_table"
        end
      end

      it "scopes the readonly connection permissions" do
        o.prepare_database_connections
        Sequel.connect(o.admin_connection_url) do |admin_conn|
          Sequel.connect(o.readonly_connection_url) do |readonly_conn|
            expect do
              readonly_conn << "CREATE TABLE my_test_table(val TEXT)"
            end.to raise_error(Sequel::DatabaseError, /permission denied for schema public/)
            admin_conn << "CREATE TABLE my_test_table(val TEXT)"

            expect do
              readonly_conn << "INSERT INTO my_test_table (val) VALUES ('x')"
            end.to raise_error(Sequel::DatabaseError, /permission denied for table my_test_table/)
            admin_conn << "INSERT INTO my_test_table (val) VALUES ('x');"

            rows = readonly_conn.fetch("SELECT * FROM my_test_table").all
            expect(rows).to(eq([{val: "x"}]))

            expect do
              readonly_conn << "DROP TABLE my_test_table"
            end.to raise_error(Sequel::DatabaseError, /must be owner of table/)
            admin_conn << "DROP TABLE my_test_table"
          end
        end
      end
    end

    describe "using database+schema+user isolation", whdbisolation: "database+schema+user" do
      it "creates a randomly named database and connection strings and the public schema" do
        o.prepare_database_connections
        expect(o).to have_attributes(
          admin_connection_url: %r(postgres://aad#{o.id}a[0-9a-f]{16}:a#{o.id}a[0-9a-f]{16}@localhost:18006/adb#{o.id}a[0-9a-f]{16}),
          readonly_connection_url: %r(postgres://aro#{o.id}a[0-9a-f]{16}:a#{o.id}a[0-9a-f]{16}@localhost:18006/adb#{o.id}a[0-9a-f]{16}),
          replication_schema: "whdb_unit_test",
        )
      end

      it "scopes the admin connection permissions" do
        o.prepare_database_connections
        Sequel.connect(o.admin_connection_url) do |admin_conn|
          admin_conn << "CREATE TABLE my_test_table(val TEXT)"
          admin_conn << "INSERT INTO my_test_table (val) VALUES ('x')"
          admin_conn << "SELECT * FROM my_test_table"
          admin_conn << "DROP TABLE my_test_table"

          admin_conn << "CREATE TABLE whdb_unit_test.my_test_table(val TEXT)"
          admin_conn << "INSERT INTO whdb_unit_test.my_test_table (val) VALUES ('x')"
          admin_conn << "SELECT * FROM whdb_unit_test.my_test_table"
          admin_conn << "DROP TABLE whdb_unit_test.my_test_table"
        end
      end

      it "scopes the readonly connection permissions" do
        o.prepare_database_connections
        Sequel.connect(o.admin_connection_url) do |admin_conn|
          admin_conn << "CREATE TABLE public.my_test_table(val TEXT)"
          admin_conn << "INSERT INTO public.my_test_table (val) VALUES ('x')"
          admin_conn << "CREATE TABLE whdb_unit_test.my_test_table(val TEXT)"
          admin_conn << "INSERT INTO whdb_unit_test.my_test_table (val) VALUES ('x')"
          admin_conn << "CREATE SCHEMA otherschema"
        end

        Sequel.connect(o.readonly_connection_url) do |readonly_conn|
          # Check readonly access to public tables.
          # NOTE: public role CANNOT create tables, since it's been revoked!
          expect do
            readonly_conn << "CREATE TABLE public.my_test_table(val TEXT)"
          end.to raise_error(Sequel::DatabaseError, /permission denied for schema public/)
          expect do
            readonly_conn << "INSERT INTO public.my_test_table (val) VALUES ('x')"
          end.to raise_error(Sequel::DatabaseError, /permission denied for schema public/)
          expect do
            readonly_conn << "DROP TABLE public.my_test_table"
          end.to raise_error(Sequel::DatabaseError, /permission denied for schema public/)
          expect do
            readonly_conn.fetch("SELECT * FROM public.my_test_table").all
          end.to raise_error(Sequel::DatabaseError, /permission denied for schema public/)

          # Check readonly cannot access another schema
          expect do
            readonly_conn << "CREATE TABLE otherschema.my_test_table(val TEXT)"
          end.to raise_error(Sequel::DatabaseError, /permission denied for schema otherschema/)
          expect do
            readonly_conn << "INSERT INTO otherschema.my_test_table (val) VALUES ('x')"
          end.to raise_error(Sequel::DatabaseError, /permission denied for schema otherschema/)
          expect do
            readonly_conn << "DROP TABLE otherschema.my_test_table"
          end.to raise_error(Sequel::DatabaseError, /permission denied for schema otherschema/)
          expect do
            readonly_conn.fetch("SELECT * FROM otherschema.my_test_table").all
          end.to raise_error(Sequel::DatabaseError, /permission denied for schema otherschema/)

          # Finally check the org schema. Modifications are denied, but select is allowed.
          expect do
            readonly_conn << "CREATE TABLE whdb_unit_test.my_test_table(val TEXT)"
          end.to raise_error(Sequel::DatabaseError, /permission denied for schema whdb_unit_test/)
          expect do
            readonly_conn << "INSERT INTO whdb_unit_test.my_test_table (val) VALUES ('x')"
          end.to raise_error(Sequel::DatabaseError, /permission denied for table my_test_table/)
          expect do
            readonly_conn << "DROP TABLE whdb_unit_test.my_test_table"
          end.to raise_error(Sequel::DatabaseError, /must be owner of table my_test_table/)
          rows = readonly_conn.fetch("SELECT * FROM whdb_unit_test.my_test_table").all
          expect(rows).to(eq([{val: "x"}]))
        end
      end
    end

    describe "using schema isolation", whdbisolation: "schema" do
      it "uses the default server url with a schema named for the org" do
        o.prepare_database_connections
        expect(o).to have_attributes(
          admin_connection_url: this_dbserver_url,
          readonly_connection_url: this_dbserver_url,
          replication_schema: "whdb_unit_test",
        )
      end
    end

    describe "using schema+user isolation", whdbisolation: "schema+user" do
      it "uses the default server url as admin, a new user for readonly, and a named schema" do
        o.prepare_database_connections
        expect(o).to have_attributes(
          admin_connection_url: this_dbserver_url,
          readonly_connection_url: %r(postgres://aro#{o.id}a[0-9a-f]{16}:a#{o.id}a[0-9a-f]{16}@localhost:18006/webhookdb_test),
          replication_schema: "whdb_unit_test",
        )
      end

      it "scopes readonly user access to just the schema" do
        o.prepare_database_connections
        Sequel.connect(o.admin_connection_url) do |admin_conn|
          admin_conn << <<~SQL
            DROP SCHEMA IF EXISTS otherschema CASCADE;
            CREATE SCHEMA otherschema;
            DROP TABLE IF EXISTS my_test_table;
            CREATE TABLE my_test_table(val TEXT);
            CREATE TABLE otherschema.my_test_table(val TEXT);
            CREATE TABLE whdb_unit_test.my_test_table(val TEXT);
            INSERT INTO my_test_table (val) VALUES ('x');
            INSERT INTO otherschema.my_test_table (val) VALUES ('x');
            INSERT INTO whdb_unit_test.my_test_table (val) VALUES ('x');
          SQL
        end

        Sequel.connect(o.readonly_connection_url) do |readonly_conn|
          # Check readonly access to public tables.
          # NOTE: public role can create tables; we don't want to revoke that.
          expect do
            readonly_conn << "CREATE TABLE my_test_table(val TEXT)"
          end.to raise_error(Sequel::DatabaseError, /relation "my_test_table" already exists/)
          expect do
            readonly_conn << "INSERT INTO my_test_table (val) VALUES ('x')"
          end.to raise_error(Sequel::DatabaseError, /permission denied for table my_test_table/)
          expect do
            readonly_conn << "DROP TABLE my_test_table"
          end.to raise_error(Sequel::DatabaseError, /must be owner of table/)
          expect do
            readonly_conn.fetch("SELECT * FROM my_test_table").all
          end.to raise_error(Sequel::DatabaseError, /permission denied for table my_test_table/)

          # Check readonly cannot access another schema
          expect do
            readonly_conn << "CREATE TABLE otherschema.my_test_table(val TEXT)"
          end.to raise_error(Sequel::DatabaseError, /permission denied for schema otherschema/)
          expect do
            readonly_conn << "INSERT INTO otherschema.my_test_table (val) VALUES ('x')"
          end.to raise_error(Sequel::DatabaseError, /permission denied for schema otherschema/)
          expect do
            readonly_conn << "DROP TABLE otherschema.my_test_table"
          end.to raise_error(Sequel::DatabaseError, /permission denied for schema otherschema/)
          expect do
            readonly_conn.fetch("SELECT * FROM otherschema.my_test_table").all
          end.to raise_error(Sequel::DatabaseError, /permission denied for schema otherschema/)

          # Finally check the org schema. Modifications are denied, but select is allowed.
          expect do
            readonly_conn << "CREATE TABLE whdb_unit_test.my_test_table(val TEXT)"
          end.to raise_error(Sequel::DatabaseError, /permission denied for schema whdb_unit_test/)
          expect do
            readonly_conn << "INSERT INTO whdb_unit_test.my_test_table (val) VALUES ('x')"
          end.to raise_error(Sequel::DatabaseError, /permission denied for table my_test_table/)
          expect do
            readonly_conn << "DROP TABLE whdb_unit_test.my_test_table"
          end.to raise_error(Sequel::DatabaseError, /must be owner of table my_test_table/)
          rows = readonly_conn.fetch("SELECT * FROM whdb_unit_test.my_test_table").all
          expect(rows).to(eq([{val: "x"}]))
        end
      end
    end

    describe "using none isolation", whdbisolation: "none" do
      it "uses the dbserver urls and public schema" do
        o.prepare_database_connections
        expect(o).to have_attributes(
          admin_connection_url: this_dbserver_url,
          readonly_connection_url: this_dbserver_url,
          replication_schema: "public",
        )
      end
    end
  end

  describe "create_public_host_cname" do
    let!(:o) { Webhookdb::Fixtures.organization.create }

    it "noops if not configured" do
      assign_connection_urls(o)
      o.create_public_host_cname
      expect(o.public_host).to eq("")
    end

    it "raises if connection urls are not set" do
      expect { o.create_public_host_cname }.to raise_error(Webhookdb::InvalidPrecondition, /must be set/)
    end

    it "raises if public host is already set" do
      assign_connection_urls(o, public_host: "already.set")
      expect { o.create_public_host_cname }.to raise_error(Webhookdb::InvalidPrecondition, /must not be set/)
    end

    it "creates the CNAME and sets the public host and cloudflare response" do
      o.update(
        key: "myorg",
        admin_connection_url_raw: "postgres://admin:adminpwd@dbsrv.rds.amazonaws.com:5432/dbname",
        readonly_connection_url_raw: "postgres://ro:ropwd@dbsrv.rds.amazonaws.com:5432/dbname",
      )

      fixture = load_fixture_data("cloudflare/create_zone_dns")
      fixture["result"].merge!("type" => "CNAME", "name" => "myorg2.db.testing.dev")
      req = stub_request(:post, "https://api.cloudflare.com/client/v4/zones/testdnszoneid/dns_records").
        with(
          body: hash_including(
            "type" => "CNAME", "name" => "myorg.db", "content" => "dbsrv.rds.amazonaws.com", "ttl" => 1,
          ),
          headers: {"Authorization" => "Bearer set-me-to-token"},
        ).to_return(status: 200, body: fixture.to_json)

      described_class.create_cname_for_connection_urls = true
      o.create_public_host_cname
      expect(req).to have_been_made
      expect(o).to have_attributes(
        admin_connection_url_raw: "postgres://admin:adminpwd@dbsrv.rds.amazonaws.com:5432/dbname",
        readonly_connection_url_raw: "postgres://ro:ropwd@dbsrv.rds.amazonaws.com:5432/dbname",
        admin_connection_url: "postgres://admin:adminpwd@myorg2.db.testing.dev:5432/dbname",
        readonly_connection_url: "postgres://ro:ropwd@myorg2.db.testing.dev:5432/dbname",
        public_host: "myorg2.db.testing.dev",
        cloudflare_dns_record_json: include("result"),
      )
    end
  end

  describe "remove_related_database" do
    let!(:o) { Webhookdb::Fixtures.organization.create(name: "unit test") }

    it "noops if connection urls are not set" do
      expect { o.remove_related_database }.to_not raise_error
    end

    describe "with database+user isolation", whdbisolation: "database+user" do
      it "removes the database and roles" do
        o.prepare_database_connections
        db_query = "SELECT count(1) FROM pg_database WHERE datistemplate = false AND datname = '#{o.dbname}'"
        user_query = "SELECT count(1) FROM pg_catalog.pg_user WHERE usename IN ('#{o.admin_user}', '#{o.readonly_user}')"
        expect(o.db.fetch(db_query).all).to(eq([{count: 1}]))
        expect(o.db.fetch(user_query).all).to(eq([{count: 2}]))
        o.remove_related_database
        expect(o.db.fetch(db_query).all).to(eq([{count: 0}]))
        expect(o.db.fetch(user_query).all).to(eq([{count: 0}]))
      end

      it "handles single db user orgs" do
        o.prepare_database_connections
        o.update(readonly_connection_url_raw: o.admin_connection_url_raw)
        db_query = "SELECT count(1) FROM pg_database WHERE datistemplate = false AND datname = '#{o.dbname}'"
        user_query = "SELECT count(1) FROM pg_catalog.pg_user WHERE usename IN ('#{o.admin_user}')"
        expect(o.db.fetch(db_query).all).to(eq([{count: 1}]))
        expect(o.db.fetch(user_query).all).to(eq([{count: 1}]))
        o.remove_related_database
        expect(o.db.fetch(db_query).all).to(eq([{count: 0}]))
        expect(o.db.fetch(user_query).all).to(eq([{count: 0}]))
      end
    end

    describe "with database+schema+user isolation", whdbisolation: "database+schema+user" do
      it "removes the database and roles" do
        o.prepare_database_connections
        db_query = "SELECT count(1) FROM pg_database WHERE datistemplate = false AND datname = '#{o.dbname}'"
        user_query = "SELECT count(1) FROM pg_catalog.pg_user WHERE usename IN ('#{o.admin_user}', '#{o.readonly_user}')"
        expect(o.db.fetch(db_query).all).to(eq([{count: 1}]))
        expect(o.db.fetch(user_query).all).to(eq([{count: 2}]))
        o.remove_related_database
        expect(o.db.fetch(db_query).all).to(eq([{count: 0}]))
        expect(o.db.fetch(user_query).all).to(eq([{count: 0}]))
      end

      it "handles single db user orgs" do
        o.prepare_database_connections
        o.update(readonly_connection_url_raw: o.admin_connection_url_raw)
        db_query = "SELECT count(1) FROM pg_database WHERE datistemplate = false AND datname = '#{o.dbname}'"
        user_query = "SELECT count(1) FROM pg_catalog.pg_user WHERE usename IN ('#{o.admin_user}')"
        expect(o.db.fetch(db_query).all).to(eq([{count: 1}]))
        expect(o.db.fetch(user_query).all).to(eq([{count: 1}]))
        o.remove_related_database
        expect(o.db.fetch(db_query).all).to(eq([{count: 0}]))
        expect(o.db.fetch(user_query).all).to(eq([{count: 0}]))
      end
    end

    describe "with schema isolation", whdbisolation: "schema" do
      it "drops the schema" do
        o.prepare_database_connections
        schema_query = "SELECT count(1) FROM information_schema.schemata WHERE schema_name = 'whdb_unit_test'"
        user_query = "SELECT count(1) FROM pg_catalog.pg_user WHERE usename IN ('#{o.admin_user}', '#{o.readonly_user}')"
        o.admin_connection do |conn|
          expect(conn.fetch(schema_query).all).to(eq([{count: 1}]))
          expect(conn.fetch(user_query).all).to(eq([{count: 1}]))
          o.remove_related_database
          expect(conn.fetch(schema_query).all).to(eq([{count: 0}]))
          expect(conn.fetch(user_query).all).to(eq([{count: 1}]))
        end
      end
    end

    describe "with schema+user isolation", whdbisolation: "schema+user" do
      it "drops the schema and readonly user" do
        o.prepare_database_connections
        schema_query = "SELECT count(1) FROM information_schema.schemata WHERE schema_name = 'whdb_unit_test'"
        user_query = "SELECT count(1) FROM pg_catalog.pg_user WHERE usename IN ('#{o.admin_user}', '#{o.readonly_user}')"
        o.admin_connection do |conn|
          expect(conn.fetch(schema_query).all).to(eq([{count: 1}]))
          expect(conn.fetch(user_query).all).to(eq([{count: 2}]))
          o.remove_related_database
          expect(conn.fetch(schema_query).all).to(eq([{count: 0}]))
          expect(conn.fetch(user_query).all).to(eq([{count: 1}]))
        end
      end
    end

    describe "with none isolation", whdbisolation: "none" do
      it "noops" do
        o.prepare_database_connections
        o.remove_related_database
      end
    end
  end

  describe "roll_database_credentials" do
    let!(:o) { Webhookdb::Fixtures.organization.create }

    def try_connect(c)
      Sequel.connect(c) { nil }
    end

    describe "with database+user (and database+schema+user) isolation", whdbisolation: "database+user" do
      it "renames users and regenerates passwords" do
        o.prepare_database_connections
        orig_ro = o.readonly_connection_url
        orig_admin = o.admin_connection_url
        expect { try_connect(orig_ro) }.to_not raise_error
        expect { try_connect(orig_admin) }.to_not raise_error
        expect do
          o.roll_database_credentials
        end.to change(o, :readonly_connection_url).and(change(o, :admin_connection_url))
        expect { try_connect(o.readonly_connection_url) }.to_not raise_error
        expect { try_connect(o.admin_connection_url) }.to_not raise_error
        expect { try_connect(orig_ro) }.to raise_error(/password authentication failed/)
        expect { try_connect(orig_admin) }.to raise_error(/password authentication failed/)
      end
    end

    describe "with schema+user isolation", whdbisolation: "schema+user" do
      it "renames users and regenerates passwords" do
        o.prepare_database_connections
        orig_ro = o.readonly_connection_url
        orig_admin = o.admin_connection_url
        expect { try_connect(orig_ro) }.to_not raise_error
        expect { try_connect(orig_admin) }.to_not raise_error
        expect do
          o.roll_database_credentials
        end.to change(o, :readonly_connection_url).and(not_change(o, :admin_connection_url))
        expect { try_connect(o.readonly_connection_url) }.to_not raise_error
        expect { try_connect(o.admin_connection_url) }.to_not raise_error
        expect { try_connect(orig_ro) }.to raise_error(/password authentication failed/)
        expect { try_connect(orig_admin) }.to_not raise_error
      end
    end

    it "errors if not using user isolation", whdbisolation: "schema" do
      assign_connection_urls(o)
      expect do
        o.roll_database_credentials
      end.to raise_error(described_class::IsolatedOperationError)
    end
  end

  describe "generate_fdw_payload" do
    let(:org) do
      Webhookdb::Fixtures.organization.create(
        name: "unit test",
        readonly_connection_url_raw: "postgres://me:l33t@somehost:5555/mydb",
        admin_connection_url_raw: "postgres://invalidurl",
      )
    end

    def create_sints
      sint_fac = Webhookdb::Fixtures.service_integration(organization: org)
      sint_fac.create(table_name: "fake_v1_abc", opaque_id: "svi_abc")
      sint_fac.create(table_name: "fake_v1_xyz", opaque_id: "svi_xyz")
    end

    describe "with database isolation" do
      before(:each) do
        # We do not want auto-cleanup, and nead isolation mode set before we run.
        described_class.isolation_mode = "database+user"
        create_sints
      end

      it "generates expected results with including all fields" do
        result = described_class.new(org).generate_fdw_payload(
          remote_server_name: "myserver",
          fetch_size: 100,
          local_schema: "myschema",
          view_schema: "vw",
        )
        expect(result).to eq(
          fdw_sql: "CREATE EXTENSION IF NOT EXISTS postgres_fdw;\nDROP SERVER IF EXISTS myserver CASCADE;\nCREATE SERVER myserver\n  FOREIGN DATA WRAPPER postgres_fdw\n  OPTIONS (host 'somehost', port '5555', dbname 'mydb', fetch_size '100');\n\nCREATE USER MAPPING FOR CURRENT_USER\n  SERVER myserver\n  OPTIONS (user 'me', password 'l33t');\n\nCREATE SCHEMA IF NOT EXISTS myschema;\nIMPORT FOREIGN SCHEMA public\n  FROM SERVER myserver\n  INTO myschema;\n\nCREATE SCHEMA IF NOT EXISTS vw;\n",
          views: {
            "svi_abc" => "CREATE MATERIALIZED VIEW IF NOT EXISTS vw.fake_v1 AS SELECT * FROM myschema.fake_v1_abc;",
            "svi_xyz" => "CREATE MATERIALIZED VIEW IF NOT EXISTS vw.fake_v1 AS SELECT * FROM myschema.fake_v1_xyz;",
          },
          views_sql: "CREATE MATERIALIZED VIEW IF NOT EXISTS vw.fake_v1 AS SELECT * FROM myschema.fake_v1_abc;\nCREATE MATERIALIZED VIEW IF NOT EXISTS vw.fake_v1 AS SELECT * FROM myschema.fake_v1_xyz;",
          compound_sql: "CREATE EXTENSION IF NOT EXISTS postgres_fdw;\nDROP SERVER IF EXISTS myserver CASCADE;\nCREATE SERVER myserver\n  FOREIGN DATA WRAPPER postgres_fdw\n  OPTIONS (host 'somehost', port '5555', dbname 'mydb', fetch_size '100');\n\nCREATE USER MAPPING FOR CURRENT_USER\n  SERVER myserver\n  OPTIONS (user 'me', password 'l33t');\n\nCREATE SCHEMA IF NOT EXISTS myschema;\nIMPORT FOREIGN SCHEMA public\n  FROM SERVER myserver\n  INTO myschema;\n\nCREATE SCHEMA IF NOT EXISTS vw;\n\n\nCREATE MATERIALIZED VIEW IF NOT EXISTS vw.fake_v1 AS SELECT * FROM myschema.fake_v1_abc;\nCREATE MATERIALIZED VIEW IF NOT EXISTS vw.fake_v1 AS SELECT * FROM myschema.fake_v1_xyz;",
        )
      end
    end

    describe "with schema isolation" do
      before(:each) do
        described_class.isolation_mode = "schema"
        create_sints
      end

      it "generates expected results with including all fields" do
        result = described_class.new(org).generate_fdw_payload(
          remote_server_name: "myserver",
          fetch_size: 100,
          local_schema: "myschema",
          view_schema: "vw",
        )
        expect(result).to eq(
          fdw_sql: "CREATE EXTENSION IF NOT EXISTS postgres_fdw;\nDROP SERVER IF EXISTS myserver CASCADE;\nCREATE SERVER myserver\n  FOREIGN DATA WRAPPER postgres_fdw\n  OPTIONS (host 'somehost', port '5555', dbname 'mydb', fetch_size '100');\n\nCREATE USER MAPPING FOR CURRENT_USER\n  SERVER myserver\n  OPTIONS (user 'me', password 'l33t');\n\nCREATE SCHEMA IF NOT EXISTS myschema;\nIMPORT FOREIGN SCHEMA whdb_unit_test\n  FROM SERVER myserver\n  INTO myschema;\n\nCREATE SCHEMA IF NOT EXISTS vw;\n",
          views: {
            "svi_abc" => "CREATE MATERIALIZED VIEW IF NOT EXISTS vw.fake_v1 AS SELECT * FROM myschema.fake_v1_abc;",
            "svi_xyz" => "CREATE MATERIALIZED VIEW IF NOT EXISTS vw.fake_v1 AS SELECT * FROM myschema.fake_v1_xyz;",
          },
          views_sql: "CREATE MATERIALIZED VIEW IF NOT EXISTS vw.fake_v1 AS SELECT * FROM myschema.fake_v1_abc;\nCREATE MATERIALIZED VIEW IF NOT EXISTS vw.fake_v1 AS SELECT * FROM myschema.fake_v1_xyz;",
          compound_sql: "CREATE EXTENSION IF NOT EXISTS postgres_fdw;\nDROP SERVER IF EXISTS myserver CASCADE;\nCREATE SERVER myserver\n  FOREIGN DATA WRAPPER postgres_fdw\n  OPTIONS (host 'somehost', port '5555', dbname 'mydb', fetch_size '100');\n\nCREATE USER MAPPING FOR CURRENT_USER\n  SERVER myserver\n  OPTIONS (user 'me', password 'l33t');\n\nCREATE SCHEMA IF NOT EXISTS myschema;\nIMPORT FOREIGN SCHEMA whdb_unit_test\n  FROM SERVER myserver\n  INTO myschema;\n\nCREATE SCHEMA IF NOT EXISTS vw;\n\n\nCREATE MATERIALIZED VIEW IF NOT EXISTS vw.fake_v1 AS SELECT * FROM myschema.fake_v1_abc;\nCREATE MATERIALIZED VIEW IF NOT EXISTS vw.fake_v1 AS SELECT * FROM myschema.fake_v1_xyz;",
        )
      end
    end
  end

  describe "migrate_replication_schema" do
    let(:org) { Webhookdb::Fixtures.organization.create(replication_schema: "abc") }

    describe "common behavior", whdbisolation: "database+user" do
      before(:each) do
        org.prepare_database_connections
      end

      it "errors for an invalid name" do
        expect do
          org.migrate_replication_schema("; drop table")
        end.to raise_error(Webhookdb::Organization::SchemaMigrationError, /this is not a valid schema name/)
      end

      it "errors if there is an ongoing migration" do
        Webhookdb::Fixtures.organization_database_migration(organization: org).started.create
        expect do
          org.migrate_replication_schema("hello")
        end.to raise_error(Webhookdb::Organization::DatabaseMigration::MigrationInProgress)
      end

      it "qualifies the argument" do
        expect do
          org.migrate_replication_schema("drop schema public cascade")
        end.to_not raise_error
        org.admin_connection do |conn|
          r = conn.fetch("SELECT count(1) FROM information_schema.schemata WHERE schema_name = 'drop schema public cascade'")
          expect(r.all).to eq([{count: 1}])
        end
      end

      it "noops if the new schema is the same as the old" do
        expect do
          org.migrate_replication_schema("abc")
        end.to raise_error(Webhookdb::Organization::SchemaMigrationError, /destination and target schema are the same/)
      end
    end

    describe "with database+user (and database+schema+user) isolation", whdbisolation: "database+user" do
      before(:each) do
        org.prepare_database_connections
      end

      it "creates the schema if needed, moves all tables, grants and revokes SELECT on the readonly user" do
        sint1 = Webhookdb::Fixtures.service_integration(organization: org).create
        sint2 = Webhookdb::Fixtures.service_integration(organization: org).create
        sint3_notable = Webhookdb::Fixtures.service_integration(organization: org).create
        sint1.replicator.create_table
        sint2.replicator.create_table
        org.admin_connection { |db| db << "CREATE TABLE abc.sometable();" }
        org.readonly_connection do |db|
          db << "SELECT 1 FROM abc.sometable"
        end

        org.migrate_replication_schema("xyz")
        # Assert the schema field was updated
        expect(org).to have_attributes(replication_schema: "xyz")
        # Assert admin and readonly can hit the new schema
        expect(sint1.replicator.admin_dataset(&:all)).to be_empty
        expect(sint1.replicator.readonly_dataset(&:all)).to be_empty
        # Also assert that new service integrations go into the correct place and are readable by admin and readonly
        sint4 = Webhookdb::Fixtures.service_integration(organization: org).create
        sint4.replicator.create_table
        expect(sint4.replicator.admin_dataset(&:all)).to be_empty
        expect(sint4.replicator.readonly_dataset(&:all)).to be_empty
        # And that readonly can't modify the new schema
        expect do
          sint4.replicator.readonly_dataset { |ds| ds.insert(at: Time.now) }
        end.to raise_error(/permission denied for table fake_v1_/)
      end

      it "handles single database user organizations" do
        sint1 = Webhookdb::Fixtures.service_integration(organization: org).create
        sint1.replicator.create_table
        org.update(readonly_connection_url_raw: org.admin_connection_url_raw)

        org.migrate_replication_schema("xyz")
        expect(org).to have_attributes(replication_schema: "xyz")
        # Expect that readonly mutations will succeed because 1) the tables were migrated and 2) it's the same as admin
        expect(sint1.replicator.admin_dataset(&:all)).to be_empty
        sint4 = Webhookdb::Fixtures.service_integration(organization: org).create
        sint4.replicator.create_table
        expect do
          sint4.replicator.readonly_dataset { |ds| ds.update(at: Time.now) }
        end.to_not raise_error
      end

      it "ensures readonly still cannot access the public schema when migrating from it" do
        org.update(replication_schema: "public")
        sint1 = Webhookdb::Fixtures.service_integration(organization: org).create
        sint1.replicator.create_table

        org.migrate_replication_schema("xyz")
        # Assert admin and readonly can hit the new schema
        expect(sint1.replicator.admin_dataset(&:all)).to be_empty
        expect(sint1.replicator.readonly_dataset(&:all)).to be_empty
        # Assert readonly cannot hit the public schema
        org.admin_connection { |db| db << "CREATE TABLE public.foo();" }
        org.readonly_connection do |db|
          expect { db << "SELECT 1 FROM public.foo" }.to raise_error(/permission denied for schema public/)
        end
      end

      it "can migrate to the public schema" do
        sint1 = Webhookdb::Fixtures.service_integration(organization: org).create
        sint1.replicator.create_table

        org.migrate_replication_schema("public")
        # Assert the schema field was updated
        expect(org).to have_attributes(replication_schema: "public")
        # Assert admin and readonly can hit the new schema
        expect(sint1.replicator.admin_dataset(&:all)).to be_empty
        expect(sint1.replicator.readonly_dataset(&:all)).to be_empty
        # Readonly can't modify the new schema
        expect do
          sint1.replicator.readonly_dataset { |ds| ds.insert(at: Time.now) }
        end.to raise_error(/permission denied for table fake_v1_/)
      end
    end

    describe "with schema+user isolation", whdbisolation: "schema+user", db: :no_transaction do
      # Need the no_transaction otherwise we get a deadlock

      before(:each) do
        org.db << "DROP SCHEMA IF EXISTS xyz CASCADE;"
        org.prepare_database_connections
      end

      it "creates the schema if needed, moves all tables, grants and revokes SELECT on the readonly user" do
        sint1 = Webhookdb::Fixtures.service_integration(organization: org).create
        sint1.replicator.create_table
        org.migrate_replication_schema("xyz")
        expect(org).to have_attributes(replication_schema: "xyz")
        expect(sint1.replicator.admin_dataset(&:all)).to be_empty
        expect(sint1.replicator.readonly_dataset(&:all)).to be_empty
        sint4 = Webhookdb::Fixtures.service_integration(organization: org).create
        sint4.replicator.create_table
        expect(sint4.replicator.admin_dataset(&:all)).to be_empty
        expect(sint4.replicator.readonly_dataset(&:all)).to be_empty
        expect do
          sint4.replicator.readonly_dataset { |ds| ds.insert(at: Time.now) }
        end.to raise_error(/permission denied for table fake_v1_/)
      end

      it "errors if migrating to the public schema" do
        expect do
          org.migrate_replication_schema("public")
        end.to raise_error(described_class::IsolatedOperationError)
      end
    end

    describe "with schema (and none) isolation", whdbisolation: ["schema", "none"].sample do
      before(:each) do
        org.update(replication_schema: "public") if described_class.isolation_mode == "none"
        org.prepare_database_connections
      end

      it "creates the schema if needed and moves all tables (does not modify user)" do
        sint1 = Webhookdb::Fixtures.service_integration(organization: org).create
        sint1.replicator.create_table
        org.migrate_replication_schema("xyz")
        expect(org).to have_attributes(replication_schema: "xyz")
        expect(sint1.replicator.admin_dataset(&:all)).to be_empty
        expect(sint1.replicator.readonly_dataset(&:all)).to be_empty
        sint4 = Webhookdb::Fixtures.service_integration(organization: org).create
        sint4.replicator.create_table
        expect(sint4.replicator.admin_dataset(&:all)).to be_empty
        expect(sint4.replicator.readonly_dataset(&:all)).to be_empty
        # Readonly should be able to insert
        sint4.replicator.readonly_dataset { |ds| ds.insert(at: Time.now, my_id: "123", data: "{}") }
      end

      it "errors if migrating to the public schema" do
        org.update(replication_schema: "def")
        expect do
          org.migrate_replication_schema("public")
        end.to raise_error(described_class::IsolatedOperationError)
      end
    end
  end

  describe "default_replication_schema" do
    it "errors if key is not set on the org" do
      o = Webhookdb::Fixtures.organization.instance
      expect do
        described_class.new(o).default_replication_schema
      end.to raise_error(Webhookdb::InvalidPrecondition)
    end

    it "uses public if not using schema isolation" do
      described_class.isolation_mode = "database+user"
      expect(Webhookdb::Fixtures.organization.create).to have_attributes(replication_schema: "public")
    end

    it "uses the org key if using schema isolation" do
      described_class.isolation_mode = "schema"
      expect(Webhookdb::Fixtures.organization.create(name: "Xyz")).to have_attributes(replication_schema: "whdb_xyz")
    end
  end
end
# rubocop:enable Layout/LineLength
