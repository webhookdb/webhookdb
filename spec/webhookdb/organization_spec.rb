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
      svc = Webhookdb::Replicator.create(sint)
      svc.create_table
    end

    it "returns expected QueryResult" do
      Sequel.connect(o.admin_connection_url) do |admin_conn|
        admin_conn << "INSERT INTO #{sint.table_name} (my_id, data) VALUES ('alpha', '{}')"
      end

      res = o.execute_readonly_query("SELECT my_id, data FROM #{sint.table_name}")

      expect(res.columns).to match([:my_id, :data])
      expect(res.rows).to eq([["alpha", {}]])
      expect(res.max_rows_reached).to be_nil
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
      expect(res.max_rows_reached).to be(true)
    end
  end

  describe "enqueue_migrate_all_replication_tables" do
    let(:org2) { Webhookdb::Fixtures.organization.create }

    it "enqueues replication table migrations for all organizations" do
      o.prepare_database_connections
      org2.prepare_database_connections

      expect(Webhookdb::Jobs::ReplicationMigration).to receive(:perform_async).with(o.id)
      expect(Webhookdb::Jobs::ReplicationMigration).to receive(:perform_async).with(org2.id)
      Webhookdb::Organization.enqueue_migrate_all_replication_tables
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
      o.migrate_replication_tables
    end
  end

  describe "register_in_stripe" do
    it "calls stripe" do
      req = stub_request(:post, "https://api.stripe.com/v1/customers").
        with(
          body: {"email" => "", "metadata" => {"org_id" => o.id.to_s}, "name" => o.name},
          headers: {"Authorization" => "Bearer lithic_stripe_api_key"},
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
