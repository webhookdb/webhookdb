# frozen_string_literal: true

RSpec.describe "Webhookdb::Organization", :db, :async do
  let(:described_class) { Webhookdb::Organization }
  let!(:o) { Webhookdb::Fixtures.organization.create }

  describe "create_if_unique" do
    it "creates the org if it does not violate a unique constraint" do
      test_org = Webhookdb::Organization.create_if_unique(name: "Acme Corp.")

      expect(test_org).to_not be_nil
      expect(test_org.name).to eq("Acme Corp.")
    end

    it "noops if org params violate a unique constraint" do
      expect do
        Webhookdb::Organization.create_if_unique(name: o.name)
      end.to_not raise_error
    end
  end

  describe "execute_readonly_query" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(organization: o) }

    before(:each) do
      o.prepare_database_connections
      svc = Webhookdb::Services.service_instance(sint)
      svc.create_table
    end

    it "returns expected QueryResult" do
      Sequel.connect(o.admin_connection_url) do |admin_conn|
        admin_conn << "INSERT INTO #{sint.table_name} (my_id, data) VALUES ('alpha', '{}')"
      end

      res = o.execute_readonly_query("SELECT my_id, data FROM #{sint.table_name}")

      expect(res.columns).to match([:my_id, :data])
      expect(res.rows).to eq([["alpha", {}]])
      expect(res.max_rows_reached).to eq(nil)
    end

    it "truncates results correctly" do
      Webhookdb::Organization.max_query_rows = 2

      # rubocop:disable Layout/LineLength
      Sequel.connect(o.admin_connection_url) do |admin_conn|
        admin_conn << "INSERT INTO #{sint.table_name} (my_id, data) VALUES ('alpha', '{}'), ('beta', '{}'), ('gamma', '{}')"
      end
      # rubocop:enable Layout/LineLength

      res = o.execute_readonly_query("SELECT my_id FROM #{sint.table_name}")
      expect(res.rows).to eq([["alpha"], ["beta"]])
      expect(res.max_rows_reached).to eq(true)
    end
  end

  describe "prepare_database_connections" do
    after(:each) do
      o.remove_related_database
    end

    it "creates a randomly named database and connection strings" do
      o.prepare_database_connections
      expect(o.admin_connection_url).to(
        match(%r(postgres://aad#{o.id}a[0-9a-f]{16}:a#{o.id}a[0-9a-f]{16}@localhost:18006/adb#{o.id}a[0-9a-f]{16})),
      )
      expect(o.readonly_connection_url).to(
        match(%r(postgres://aro#{o.id}a[0-9a-f]{16}:a#{o.id}a[0-9a-f]{16}@localhost:18006/adb#{o.id}a[0-9a-f]{16})),
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

    it "errors if there are already database connections on the object" do
      expect { o.prepare_database_connections }.to_not raise_error
      expect do
        o.prepare_database_connections
      end.to raise_error(Webhookdb::InvalidPrecondition, "connections already set")
    end
  end

  describe "create_public_host_cname" do
    after(:each) do
      described_class::DbBuilder.reset_configuration
    end

    it "noops if not configured" do
      o.update(
        admin_connection_url_raw: "postgres://pg/db",
        readonly_connection_url_raw: "postgres://pg/db",
      )
      o.create_public_host_cname
      expect(o.public_host).to eq("")
    end

    it "raises if connection urls are not set" do
      expect { o.create_public_host_cname }.to raise_error(Webhookdb::InvalidPrecondition, /must be set/)
    end

    it "raises if public host is already set" do
      o.update(
        admin_connection_url_raw: "postgres://pg/db",
        readonly_connection_url_raw: "postgres://pg/db",
        public_host: "already.set",
      )
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

      described_class::DbBuilder.create_cname_for_connection_urls = true
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
    after(:each) do
      o.remove_related_database
    end

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

    it "noops if connection urls are not set" do
      expect { o.remove_related_database }.to_not raise_error
    end
  end

  describe "roll_database_credentials" do
    after(:each) do
      o.remove_related_database
    end

    def try_connect(c)
      Sequel.connect(c) { nil }
    end

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

  describe "get_stripe_billing_portal_url" do
    it "raises error if org has no stripe customer ID" do
      o.update(stripe_customer_id: "")
      expect { o.get_stripe_billing_portal_url }.to raise_error(Webhookdb::InvalidPrecondition)
    end

    it "returns session url if stripe customer is registered" do
      req = stub_request(:post, "https://api.stripe.com/v1/billing_portal/sessions").
        with(
          body: {"customer" => "foobar", "return_url" => "http://localhost:18002/jump/portal-return"},
        ).
        to_return(
          status: 200,
          body: {
            url: "https://billing.stripe.com/session/foobar",
          }.to_json,
        )

      o.update(stripe_customer_id: "foobar")
      url = o.get_stripe_billing_portal_url
      expect(req).to have_been_made
      expect(url).to eq("https://billing.stripe.com/session/foobar")
    end
  end

  describe "get_stripe_checkout_url" do
    it "raises error if org has no stripe customer ID" do
      o.update(stripe_customer_id: "")
      expect { o.get_stripe_checkout_url("price_a") }.to raise_error(Webhookdb::InvalidPrecondition)
    end

    it "returns checkout url if stripe customer is registered" do
      req = stub_request(:post, "https://api.stripe.com/v1/checkout/sessions").
        to_return(
          status: 200,
          body: {url: "https://checkout.stripe.com/pay/cs_test_foobar"}.to_json,
        )

      o.update(stripe_customer_id: "foobar")
      url = o.get_stripe_checkout_url("price_a")
      expect(req).to have_been_made
      expect(url).to eq("https://checkout.stripe.com/pay/cs_test_foobar")
    end
  end

  describe "validations" do
    it "requires all of the connections to be present, or none" do
      expect do
        o.db.transaction do
          o.readonly_connection_url_raw = ""
          o.admin_connection_url_raw = "postgres://xyz/abc"
          o.save_changes
        end
      end.to raise_error(Sequel::ValidationFailed, match(/must all be set or all be present/))
    end

    it "must be valid as a CNAME" do
      expect do
        o.update(key: "abc" * 30)
      end.to raise_error(Sequel::ValidationFailed, match(/key is not valid as a CNAME/))
      expect { o.update(key: "0abc") }.to raise_error(Sequel::ValidationFailed, match(/key is not valid as a CNAME/))
      expect { o.update(key: "zeroabc") }.to_not raise_error
    end
  end

  describe "#all_webhook_subscriptions" do
    it "returns the webhook subs associated with the org and all integrations" do
      org_sub = Webhookdb::Fixtures.webhook_subscription.create(organization: o)
      sint_fac = Webhookdb::Fixtures.service_integration(organization: o)
      sint1_sub = Webhookdb::Fixtures.webhook_subscription.create(service_integration: sint_fac.create)
      sint2_sub = Webhookdb::Fixtures.webhook_subscription.create(service_integration: sint_fac.create)
      _other_sub = Webhookdb::Fixtures.webhook_subscription.create

      expect(o.all_webhook_subscriptions).to have_same_ids_as(org_sub, sint1_sub, sint2_sub)
    end
  end

  describe "active_subscription?" do
    before(:each) do
      Webhookdb::Subscription.where(stripe_customer_id: o.stripe_customer_id).delete
    end

    it "returns true if org has a subscription with status 'active'" do
      Webhookdb::Fixtures.subscription.active.for_org(o).create
      expect(o).to be_active_subscription
    end

    it "returns false if org has a subscription with status 'canceled'" do
      Webhookdb::Fixtures.subscription.canceled.for_org(o).create
      expect(o).to_not be_active_subscription
    end

    it "returns false if org does not have subscription" do
      expect(o).to_not be_active_subscription
    end
  end

  describe "can_add_new_integration?" do
    it "returns true if org has active subscription" do
      Webhookdb::Fixtures.subscription.active.for_org(o).create
      expect(o.can_add_new_integration?).to eq(true)
    end

    it "returns true if org has no active subscription and uses fewer than max free integrations" do
      Webhookdb::Fixtures.subscription.canceled.for_org(o).create
      expect(o.can_add_new_integration?).to eq(true)
    end

    it "returns false if org has no active subscription and uses at least max free integrations" do
      Webhookdb::Subscription.max_free_integrations = 1
      sint = Webhookdb::Fixtures.service_integration.create(organization: o)
      expect(o.can_add_new_integration?).to eq(false)
      Webhookdb::Subscription.max_free_integrations = 2
    end
  end

  describe "available services" do
    it "filters out services that the org should not have access to" do
      # by default the org does not have the "internal" feature role assigned to it,
      # so our "fake" integrations should not show up in this list
      expect(o.available_service_names).to_not include("fake_v1", "fake_with_enrichments_v1")
    end

    it "includes services that the org should have access to" do
      internal_role = Webhookdb::Role.create(name: "internal")
      o.add_feature_role(internal_role)
      expect(o.available_service_names).to include("fake_v1", "fake_with_enrichments_v1")
    end
  end

  describe "generate_fdw_payload" do
    let(:org) do
      Webhookdb::Fixtures.organization.create(
        readonly_connection_url_raw: "postgres://me:l33t@somehost:5555/mydb",
        admin_connection_url_raw: "postgres://invalidurl",
      )
    end

    before(:each) do
      sint_fac = Webhookdb::Fixtures.service_integration(organization: org)
      sint_fac.create(table_name: "fake_v1_abc", opaque_id: "svi_abc")
      sint_fac.create(table_name: "fake_v1_xyz", opaque_id: "svi_xyz")
    end

    it "generates expected results with including all fields" do
      result = Webhookdb::Organization::DbBuilder.new(org).generate_fdw_payload(
        remote_server_name: "myserver",
        fetch_size: 100,
        local_schema: "myschema",
        view_schema: "vw",
      )
      # rubocop:disable Layout/LineLength
      expect(result).to eq(
        fdw_sql: "CREATE EXTENSION IF NOT EXISTS postgres_fdw;\nDROP SERVER IF EXISTS myserver CASCADE;\nCREATE SERVER myserver\n  FOREIGN DATA WRAPPER postgres_fdw\n  OPTIONS (host 'somehost', port '5555', dbname 'mydb', fetch_size '100');\n\nCREATE USER MAPPING FOR CURRENT_USER\n  SERVER myserver\n  OPTIONS (user 'me', password 'l33t');\n\nCREATE SCHEMA IF NOT EXISTS myschema;\nIMPORT FOREIGN SCHEMA public\n  FROM SERVER myserver\n  INTO myschema;\n\nCREATE SCHEMA IF NOT EXISTS vw;\n",
        views: {
          "svi_abc" => "CREATE MATERIALIZED VIEW IF NOT EXISTS vw.fake_v1 AS SELECT * FROM myschema.fake_v1_abc;",
          "svi_xyz" => "CREATE MATERIALIZED VIEW IF NOT EXISTS vw.fake_v1 AS SELECT * FROM myschema.fake_v1_xyz;",
        },
        views_sql: "CREATE MATERIALIZED VIEW IF NOT EXISTS vw.fake_v1 AS SELECT * FROM myschema.fake_v1_abc;\nCREATE MATERIALIZED VIEW IF NOT EXISTS vw.fake_v1 AS SELECT * FROM myschema.fake_v1_xyz;",
        compound_sql: "CREATE EXTENSION IF NOT EXISTS postgres_fdw;\nDROP SERVER IF EXISTS myserver CASCADE;\nCREATE SERVER myserver\n  FOREIGN DATA WRAPPER postgres_fdw\n  OPTIONS (host 'somehost', port '5555', dbname 'mydb', fetch_size '100');\n\nCREATE USER MAPPING FOR CURRENT_USER\n  SERVER myserver\n  OPTIONS (user 'me', password 'l33t');\n\nCREATE SCHEMA IF NOT EXISTS myschema;\nIMPORT FOREIGN SCHEMA public\n  FROM SERVER myserver\n  INTO myschema;\n\nCREATE SCHEMA IF NOT EXISTS vw;\n\n\nCREATE MATERIALIZED VIEW IF NOT EXISTS vw.fake_v1 AS SELECT * FROM myschema.fake_v1_abc;\nCREATE MATERIALIZED VIEW IF NOT EXISTS vw.fake_v1 AS SELECT * FROM myschema.fake_v1_xyz;",
      )
      # rubocop:enable Layout/LineLength
    end
  end

  describe "migrate_replication_schema" do
    let(:org) { Webhookdb::Fixtures.organization.create(replication_schema: "abc") }

    before(:each) do
      org.prepare_database_connections
    end

    after(:each) do
      org.remove_related_database
    end

    it "creates the schema if needed, moves all tables, grants and revokes SELECT on the readonly user" do
      sint1 = Webhookdb::Fixtures.service_integration(organization: org).create
      sint2 = Webhookdb::Fixtures.service_integration(organization: org).create
      sint3_notable = Webhookdb::Fixtures.service_integration(organization: org).create
      sint1.service_instance.create_table
      sint2.service_instance.create_table
      org.admin_connection { |db| db << "CREATE TABLE abc.sometable();" }
      org.readonly_connection do |db|
        db << "SELECT 1 FROM abc.sometable"
      end

      org.migrate_replication_schema("xyz")
      # Assert the schema field was updated
      expect(org).to have_attributes(replication_schema: "xyz")
      # Assert admin and readonly can hit the new schema
      expect(sint1.service_instance.admin_dataset(&:all)).to be_empty
      expect(sint1.service_instance.readonly_dataset(&:all)).to be_empty
      # Also assert that new service integrations go into the correct place and are readable by admin and readonly
      sint4 = Webhookdb::Fixtures.service_integration(organization: org).create
      sint4.service_instance.create_table
      expect(sint4.service_instance.admin_dataset(&:all)).to be_empty
      expect(sint4.service_instance.readonly_dataset(&:all)).to be_empty
      # And that readonly can't modify the new schema
      expect do
        sint4.service_instance.readonly_dataset { |ds| ds.insert(at: Time.now) }
      end.to raise_error(/permission denied for table fake_v1_/)
    end

    it "ensures readonly still cannot access the public schema when migrating from it" do
      org.update(replication_schema: "public")
      sint1 = Webhookdb::Fixtures.service_integration(organization: org).create
      sint1.service_instance.create_table

      org.migrate_replication_schema("xyz")
      # Assert admin and readonly can hit the new schema
      expect(sint1.service_instance.admin_dataset(&:all)).to be_empty
      expect(sint1.service_instance.readonly_dataset(&:all)).to be_empty
      # Assert readonly cannot hit the public schema
      org.admin_connection { |db| db << "CREATE TABLE public.foo();" }
      org.readonly_connection do |db|
        expect { db << "SELECT 1 FROM public.foo" }.to raise_error(/permission denied for schema public/)
      end
    end

    it "can migrate to the public schema" do
      sint1 = Webhookdb::Fixtures.service_integration(organization: org).create
      sint1.service_instance.create_table

      org.migrate_replication_schema("public")
      # Assert the schema field was updated
      expect(org).to have_attributes(replication_schema: "public")
      # Assert admin and readonly can hit the new schema
      expect(sint1.service_instance.admin_dataset(&:all)).to be_empty
      expect(sint1.service_instance.readonly_dataset(&:all)).to be_empty
      # Readonly can't modify the new schema
      expect do
        sint1.service_instance.readonly_dataset { |ds| ds.insert(at: Time.now) }
      end.to raise_error(/permission denied for table fake_v1_/)
    end

    it "errors for an invalid name" do
      expect do
        org.migrate_replication_schema("; drop table")
      end.to raise_error(described_class::SchemaMigrationError, /this is not a valid schema name/)
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
    end

    it "noops if the new schema is the same as the old" do
      expect do
        org.migrate_replication_schema("abc")
      end.to raise_error(described_class::SchemaMigrationError, /destination and target schema are the same/)
    end
  end
end
