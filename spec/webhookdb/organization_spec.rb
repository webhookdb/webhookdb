# frozen_string_literal: true

RSpec.describe "Webhookdb::Organization", :async, :db do
  let(:described_class) { Webhookdb::Organization }
  let!(:o) { Webhookdb::Fixtures.organization.create }

  describe "associations" do
    it "knows about all sync targets" do
      sint = Webhookdb::Fixtures.service_integration(organization: o).create
      st = Webhookdb::Fixtures.sync_target(service_integration: sint).create
      expect(o.refresh.all_sync_targets).to have_same_ids_as(st)
      # Test eager loader
      expect(Webhookdb::SyncTarget.all.first.organization.all_sync_targets).to have_same_ids_as(st)
    end

    it "knows about all webhook subscriptions" do
      sint = Webhookdb::Fixtures.service_integration(organization: o).create
      sint_sub = Webhookdb::Fixtures.webhook_subscription(service_integration: sint).create
      org_sub = Webhookdb::Fixtures.webhook_subscription(organization: o).create

      unrelated_org = Webhookdb::Fixtures.webhook_subscription.for_org.create
      unrelated_sint = Webhookdb::Fixtures.webhook_subscription.for_service_integration.create

      expect(o.refresh.all_webhook_subscriptions).to have_same_ids_as(sint_sub, org_sub)
      # Test eager loader
      eager_org = Webhookdb::ServiceIntegration.where(id: sint.id).all.first.organization
      expect(eager_org.all_webhook_subscriptions).to have_same_ids_as(sint_sub, org_sub)
    end
  end

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
      svc = Webhookdb::Replicator.create(sint)
      svc.create_table
    end

    it "returns expected QueryResult" do
      Sequel.connect(o.admin_connection_url) do |admin_conn|
        admin_conn << "INSERT INTO #{sint.table_name} (my_id, data) VALUES ('alpha', '{}')"
      end

      res = o.execute_readonly_query("SELECT my_id, data FROM #{sint.table_name}")
      expect(res).to have_attributes(
        columns: [:my_id, :data],
        rows: [["alpha", {}]],
        max_rows_reached: be(false),
      )
    end

    it "truncates results correctly" do
      # rubocop:disable Layout/LineLength
      Sequel.connect(o.admin_connection_url) do |admin_conn|
        admin_conn << "INSERT INTO #{sint.table_name} (my_id, data) VALUES ('alpha', '{}'), ('beta', '{}'), ('gamma', '{}')"
      end
      # rubocop:enable Layout/LineLength

      Webhookdb::Organization.max_query_rows = 2
      expect(o.execute_readonly_query("SELECT my_id FROM #{sint.table_name}")).to have_attributes(
        rows: [["alpha"], ["beta"]],
        max_rows_reached: be(true),
      )

      Webhookdb::Organization.max_query_rows = 3
      expect(o.execute_readonly_query("SELECT my_id FROM #{sint.table_name}")).to have_attributes(
        rows: have_length(3),
        max_rows_reached: be(false),
      )
    end

    it "uses the organization max query rows if not null" do
      Sequel.connect(o.admin_connection_url) do |admin_conn|
        admin_conn << "INSERT INTO #{sint.table_name} (my_id, data) VALUES ('alpha', '{}'), ('beta', '{}')"
      end
      Webhookdb::Organization.max_query_rows = 1
      expect(o.execute_readonly_query("SELECT my_id FROM #{sint.table_name}")).to have_attributes(
        rows: have_length(1),
        max_rows_reached: true,
      )

      o.update(max_query_rows: 99_999)
      expect(o.execute_readonly_query("SELECT my_id FROM #{sint.table_name}")).to have_attributes(
        rows: have_length(2),
        max_rows_reached: false,
      )
    end
  end

  describe "enqueue_migrate_all_replication_tables" do
    let(:org2) { Webhookdb::Fixtures.organization.create }

    it "enqueues replication table migrations for all organizations", sidekiq: :fake do
      o.prepare_database_connections
      org2.prepare_database_connections
      t = trunc_time(Time.now)
      Timecop.freeze(t) do
        Webhookdb::Organization.enqueue_migrate_all_replication_tables
      end

      expect(Sidekiq).to have_queue.consisting_of(
        job_hash(
          Webhookdb::Jobs::ReplicationMigration,
          args: [o.id, "1970-01-01T00:00:00Z"],
          at: match_time(t + 2.seconds),
        ),
        job_hash(
          Webhookdb::Jobs::ReplicationMigration,
          args: [org2.id, "1970-01-01T00:00:00Z"],
          at: match_time(t + 2.seconds),
        ),
      )
    end
  end

  describe "migrate_replication_tables", :fake_replicator do
    let(:fake_sint) { Webhookdb::Fixtures.service_integration.create(organization: o) }
    let(:fake) { fake_sint.replicator }

    before(:each) do
      o.prepare_database_connections
      fake.create_table
    end

    after(:each) do
      o.remove_related_database
    end

    it "adds missing columns only from changed tables and backfills values" do
      fake.admin_dataset do |ds|
        expect(ds.columns).to contain_exactly(:pk, :my_id, :at, :data)
        ds.multi_insert(
          [
            {my_id: "abc123", data: {from: "Canada"}.to_json},
            {my_id: "def456", data: {from: "Iceland"}.to_json},
          ],
        )
      end
      expect(o.service_integrations.first).to receive(:replicator).and_return(fake)
      fake.define_singleton_method(:_denormalized_columns) do
        [
          Webhookdb::Replicator::Column.new(:from, Webhookdb::DBAdapter::ColumnTypes::TEXT),
        ]
      end
      expect(fake).to receive(:ensure_all_columns).and_call_original

      o.migrate_replication_tables

      fake.admin_dataset do |ds|
        expect(ds.columns).to contain_exactly(:pk, :my_id, :at, :data, :from)
        expect(ds.all).to contain_exactly(
          include(my_id: "abc123", from: "Canada"),
          include(my_id: "def456", from: "Iceland"),
        )
      end
    end

    it "does not add columns if none are considered missing" do
      expect(o.service_integrations.first).to receive(:replicator).and_return(fake)
      expect(fake).to_not receive(:ensure_all_columns)
      o.migrate_replication_tables
    end

    it "considers structural columns like enrichments" do
      fake.admin_dataset do |ds|
        expect(ds.columns).to contain_exactly(:pk, :my_id, :at, :data)
      end
      expect(o.service_integrations.first).to receive(:replicator).and_return(fake)
      fake.define_singleton_method(:_store_enrichment_body?) { true }
      expect(fake).to receive(:ensure_all_columns).and_call_original
      o.migrate_replication_tables
      fake.admin_dataset do |ds|
        expect(ds.columns).to contain_exactly(:pk, :my_id, :at, :data, :enrichment)
      end
    end

    it "creates a sequence if the integration requires it" do
      Webhookdb::Replicator::Fake.requires_sequence = true
      _ = fake_sint
      o.migrate_replication_tables
      expect(o.db.select(Sequel.function(:nextval, fake_sint.sequence_name)).single_value).to eq(1)
      expect(o.db.select(Sequel.function(:nextval, fake_sint.sequence_name)).single_value).to eq(2)
    end

    it "does not create a sequence once created" do
      Webhookdb::Replicator::Fake.requires_sequence = true
      _ = fake_sint
      o.migrate_replication_tables
      expect { o.migrate_replication_tables }.to_not raise_error
    end

    it "creates newly added indices" do
      fake.admin_dataset do |ds|
        indexes = ds.from(:pg_indexes).where(tablename: fake.service_integration.table_name).select_map(:indexname)
        expect(indexes).to have_length(3)
        expect(indexes).to include(end_with("_pkey"))
        expect(indexes).to include(end_with("_my_id_key"))
        expect(indexes).to include(end_with("_at_idx"))
      end
      expect(o.service_integrations.first).to receive(:replicator).and_return(fake)
      fake.define_singleton_method(:_extra_index_specs) do
        [Webhookdb::Replicator::IndexSpec.new(columns: [:at, :my_id])]
      end

      o.migrate_replication_tables

      fake.admin_dataset do |ds|
        indexes = ds.from(:pg_indexes).where(tablename: fake.service_integration.table_name).select_map(:indexname)
        expect(indexes).to have_length(4)
        expect(indexes).to include(end_with("_pkey"))
        expect(indexes).to include(end_with("_my_id_key"))
        expect(indexes).to include(end_with("_at_idx"))
        expect(indexes).to include(end_with("_my_id_idx"))
      end
    end
  end

  describe "register_in_stripe" do
    it "calls stripe" do
      req = stub_request(:post, "https://api.stripe.com/v1/customers").
        with(
          body: {"email" => "", "metadata" => {"org_id" => o.id.to_s}, "name" => o.name},
          headers: {"Authorization" => "Bearer whdb_stripe_api_key"},
        ).
        to_return(body: load_fixture_data("stripe/customer_create", raw: true))
      o.stripe_customer_id = ""
      o.register_in_stripe
      expect(req).to have_been_made
      expect(o).to have_attributes(stripe_customer_id: "cus_MNfUZylqDB2oa0")
    end

    it "raises if already registered" do
      o.stripe_customer_id = "cus_xyz"
      expect { o.register_in_stripe }.to raise_error(Webhookdb::InvalidPrecondition)
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
    it "cannot have an org name that begins with an integer" do
      expect do
        o.update(name: "123abc" * 30)
      end.to raise_error(Sequel::ValidationFailed, match(/name can't begin with a digit/))
    end

    it "requires all of the connections to be present, or none" do
      expect do
        o.db.transaction do
          o.readonly_connection_url_raw = nil
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
      expect(o.can_add_new_integration?).to be(true)
    end

    it "returns true if org has no active subscription and uses fewer than max free integrations" do
      Webhookdb::Fixtures.subscription.canceled.for_org(o).create
      expect(o.can_add_new_integration?).to be(true)
    end

    it "returns false if org has no active subscription and uses at least max free integrations" do
      Webhookdb::Subscription.max_free_integrations = 1
      sint = Webhookdb::Fixtures.service_integration.create(organization: o)
      expect(o.can_add_new_integration?).to be(false)
      Webhookdb::Subscription.max_free_integrations = 2
    end
  end

  describe "with_identifier dataset" do
    let(:org) { Webhookdb::Fixtures.organization.create }

    it "returns correct dataset when identifier is an id" do
      ds = Webhookdb::Organization.with_identifier(org.id.to_s)
      expect(ds[id: org.id]).to_not be_nil
      expect(ds.all).to have_length(1)
    end

    it "returns correct dataset when identifier is a key" do
      ds = Webhookdb::Organization.with_identifier(org.key)
      expect(ds[id: org.id]).to_not be_nil
      expect(ds.all).to have_length(1)
    end

    it "returns correct dataset when identifier is a name" do
      ds = Webhookdb::Organization.with_identifier(org.name)
      expect(ds[id: org.id]).to_not be_nil
      expect(ds.all).to have_length(1)
    end

    it "returns multiple results" do
      org_ab = Webhookdb::Fixtures.organization.create(name: "a", key: "b")
      org_ba = Webhookdb::Fixtures.organization.create(name: "b", key: "a")
      ds = Webhookdb::Organization.with_identifier("a")
      expect(ds[id: org_ab.id]).to_not be_nil
      expect(ds[id: org_ba.id]).to_not be_nil
      expect(ds.all).to have_length(2)
    end
  end

  describe "available replicators" do
    it "filters out replicators that the org should not have access to" do
      # by default the org does not have the "internal" feature role assigned to it,
      # so our "fake" integrations should not show up in this list
      expect(o.available_replicator_names).to_not include("fake_v1", "fake_with_enrichments_v1")
    end

    it "includes replicators that the org should have access to" do
      internal_role = Webhookdb::Role.create(name: "internal")
      o.add_feature_role(internal_role)
      expect(o.available_replicator_names).to include("fake_v1", "fake_with_enrichments_v1")
    end
  end
end
