# frozen_string_literal: true

require "webhookdb/service_integration"

RSpec.describe "Webhookdb::ServiceIntegration", :db do
  let(:described_class) { Webhookdb::ServiceIntegration }

  let!(:sint) { Webhookdb::Fixtures.service_integration.create }
  let!(:org) { sint.organization }

  describe "#all_webhook_subscriptions" do
    it "returns the webhook subs associated with both the integration and the org" do
      sint_sub = Webhookdb::Fixtures.webhook_subscription.create(service_integration: sint)
      org_sub = Webhookdb::Fixtures.webhook_subscription.create(organization: org)
      other_sint_for_org = Webhookdb::Fixtures.service_integration(organization: org).create
      _other_sint_sub = Webhookdb::Fixtures.webhook_subscription.create(service_integration: other_sint_for_org)

      unrelated_org = Webhookdb::Fixtures.webhook_subscription.for_org.create
      unrelated_sint = Webhookdb::Fixtures.webhook_subscription.for_service_integration.create

      expect(sint.all_webhook_subscriptions).to have_same_ids_as(sint_sub, org_sub)
      # Test eagering
      eo_sint = Webhookdb::Organization.where(id: sint.organization_id).all.first.service_integrations.first
      expect(eo_sint.all_webhook_subscriptions).to have_same_ids_as(
        sint_sub, org_sub,
      )
    end
  end

  describe "plan_supports_integration?", reset_configuration: Webhookdb::Subscription do
    before(:each) do
      Webhookdb::Subscription.billing_enabled = true
    end

    it "returns true if the organization has an active subscription" do
      Webhookdb::Fixtures.subscription.active.for_org(sint.organization).create
      expect(sint.plan_supports_integration?).to be(true)
    end

    it "returns true if the organization has no active subscription and sint is in first integrations" do
      expect(sint.plan_supports_integration?).to be(true)
    end

    it "returns false if the organization has no subscription and sint is not in first integrations" do
      twilio_sint = Webhookdb::ServiceIntegration.create(
        {
          opaque_id: SecureRandom.hex(6),
          table_name: SecureRandom.hex(2),
          service_name: "twilio_sms_v1",
          organization: sint.organization,
        },
      )

      shopify_sint = Webhookdb::ServiceIntegration.create(
        {
          opaque_id: SecureRandom.hex(6),
          table_name: SecureRandom.hex(2),
          service_name: "shopify_order_v1",
          organization: sint.organization,
        },
      )

      expect(twilio_sint.plan_supports_integration?).to be(true)
      expect(shopify_sint.plan_supports_integration?).to be(false)
    end
  end

  describe "stats" do
    before(:each) do
      # successful webhooks
      Webhookdb::Fixtures.logged_webhook(service_integration_opaque_id: sint.opaque_id).success.create
      Webhookdb::Fixtures.logged_webhook(service_integration_opaque_id: sint.opaque_id).success.create
      Webhookdb::Fixtures.logged_webhook(service_integration_opaque_id: sint.opaque_id).success.create
      # rejected webhooks
      Webhookdb::Fixtures.logged_webhook(service_integration_opaque_id: sint.opaque_id).failure.create
    end

    it "returns expected information" do
      stats = sint.stats
      # rubocop:disable Naming/VariableNumber
      expect(stats.as_json).to include(
        message: "",
        count_last_7_days: 4,
        count_last_7_days_formatted: "4",
        rejected_last_7_days: 1,
        rejected_last_7_days_formatted: "1",
        rejected_last_7_days_percent: 0.25,
        rejected_last_7_days_percent_formatted: "25.0%",
        success_last_7_days: 3,
        success_last_7_days_formatted: "3",
        success_last_7_days_percent: 0.75,
        success_last_7_days_percent_formatted: "75.0%",
        successful_of_last_10: 3,
        successful_of_last_10_formatted: "3",
        rejected_of_last_10: 1,
        rejected_of_last_10_formatted: "1",
        display_headers: be_an(Array),
      )
      # rubocop:enable Naming/VariableNumber
    end

    it "returns 'no webhooks logged' message in 'table' format" do
      Webhookdb::LoggedWebhook.where(service_integration_opaque_id: sint.opaque_id).delete
      stats = sint.stats
      expect(stats.as_json).to include(message: match(/We have no record of receiving webhooks/))
    end

    it "can use display headers to describe itself" do
      stats = sint.stats
      expect(stats.display_headers.map { |k, f| [f, stats.data[k]] }).to eq(
        [
          ["Count Last 7 Days", "4"],
          ["Successful Last 7 Days", "3"],
          ["Successful Last 7 Days %", "75.0%"],
          ["Rejected Last 7 Days", "1"],
          ["Rejected Last 7 Days %", "25.0%"],
          ["Successful Of Last 10 Webhooks", "3"],
          ["Rejected Of Last 10 Webhooks", "1"],
        ],
      )
    end
  end

  describe "rename_table" do
    before(:each) do
      org.prepare_database_connections
      sint.replicator.create_table
    end

    after(:each) do
      org.remove_related_database
    end

    it "renames the given table" do
      sint.rename_table(to: "table5")

      expect(org.readonly_connection { |db| db[:table5].all }).to eq([])
      expect(sint.table_name).to eq("table5")
    end

    it "errors for an invalid name" do
      expect do
        sint.rename_table(to: "foo-bar")
      end.to raise_error(Webhookdb::DBAdapter::InvalidIdentifier, /must start with a letter/)
    end

    it "errors if the target table already exists" do
      org.admin_connection { |db| db << "CREATE TABLE table5(id INTEGER);" }
      expect do
        sint.rename_table(to: "table5")
      end.to raise_error(described_class::TableRenameError, /already a table named/)
    end

    it "errors if the org is being migrated" do
      Webhookdb::Fixtures.organization_database_migration(organization: org).started.create
      expect do
        sint.rename_table(to: "foo-bar")
      end.to raise_error(Webhookdb::Organization::DatabaseMigration::MigrationInProgress)
    end
  end

  describe "sequence creation", :fake_replicator do
    it "creates a sequence if needed" do
      Webhookdb::Replicator::Fake.requires_sequence = true
      sint = Webhookdb::Fixtures.service_integration.create
      sint.ensure_sequence
      expect(sint.db.select(Sequel.function(:nextval, sint.sequence_name)).single_value).to eq(1)
      expect(sint.db.select(Sequel.function(:nextval, sint.sequence_name)).single_value).to eq(2)
      expect(sint.sequence_nextval).to eq(3)
    end

    it "errors if trying to create a sequence when it's not needed" do
      sint = Webhookdb::Fixtures.service_integration.create
      expect { sint.ensure_sequence }.to raise_error(Webhookdb::InvalidPrecondition)
    end
  end

  describe "destroy_self_and_all_dependents" do
    it "destroys a single service integration if it has no dependents" do
      org.prepare_database_connections
      sint.replicator.create_table

      sint.destroy_self_and_all_dependents

      expect(org.service_integrations_dataset.all).to be_empty

      expect do
        sint.replicator.admin_dataset(&:count)
      end.to raise_error(Sequel::DatabaseError, /PG::UndefinedTable/)
    ensure
      org.remove_related_database
    end

    it "destroys service integrations recursively" do
      fac = Webhookdb::Fixtures.service_integration(organization: org)
      dep_sint = fac.depending_on(sint).create
      dep_dep_sint = fac.depending_on(dep_sint).create

      org.prepare_database_connections
      sint.replicator.create_table
      dep_sint.replicator.create_table
      dep_dep_sint.replicator.create_table

      sint.destroy_self_and_all_dependents

      expect(org.service_integrations_dataset.all).to be_empty

      expect do
        sint.replicator.admin_dataset(&:count)
      end.to raise_error(Sequel::DatabaseError, /PG::UndefinedTable/)
      expect do
        dep_sint.replicator.admin_dataset(&:count)
      end.to raise_error(Sequel::DatabaseError, /PG::UndefinedTable/)
      expect do
        dep_dep_sint.replicator.admin_dataset(&:count)
      end.to raise_error(Sequel::DatabaseError, /PG::UndefinedTable/)
    ensure
      org.remove_related_database
    end

    it "works if the database is not set up" do
      sint.destroy_self_and_all_dependents
      expect(org.service_integrations_dataset.all).to be_empty
    end
  end

  describe "api key" do
    it "generates a secure, unique key" do
      sint = Webhookdb::Fixtures.service_integration.create(opaque_id: "oid")
      k = sint.new_api_key
      expect(k).to start_with("sk/oid/")
      expect(k).to have_length(be > 40)
    end

    it "can look up a service integration based on its api key" do
      sint1 = Webhookdb::Fixtures.service_integration.with_api_key.create
      sint2 = Webhookdb::Fixtures.service_integration.with_api_key.create

      expect(described_class.for_api_key(sint1.webhookdb_api_key)).to be === sint1
      expect(described_class.for_api_key("not a real key")).to be_nil
    end
  end

  describe "::create_disambiguated" do
    it "uses the service name with a unique tag as table name if no table name is provided" do
      organization = Webhookdb::Fixtures.organization.create
      sint = Webhookdb::ServiceIntegration.create_disambiguated("fake_v1", organization:)
      expect(sint.table_name).to match(/fake_v1_([a-z\d]){4}/)
    end
  end

  describe "recursive dependents/dependencies" do
    it "returns the expected dependents and dependency chain" do
      fac = Webhookdb::Fixtures.service_integration
      a = fac.create
      a_a = fac.create(depends_on: a)
      a_b = fac.create(depends_on: a)
      a_a_a = fac.create(depends_on: a_a)
      a_a_b = fac.create(depends_on: a_a)
      a_b_a = fac.create(depends_on: a_b)
      expect(a.recursive_dependencies).to be_empty
      expect(a.recursive_dependents).to have_same_ids_as(a_a, a_b, a_a_a, a_a_b, a_b_a).ordered

      expect(a_a.recursive_dependencies).to have_same_ids_as(a).ordered
      expect(a_a.recursive_dependents).to have_same_ids_as(a_a_a, a_a_b).ordered

      expect(a_a_b.recursive_dependencies).to have_same_ids_as(a_a, a).ordered
      expect(a_a_b.recursive_dependents).to be_empty

      a_a_a_a = fac.create(depends_on: a_a_a)
      expect(a_a_a_a.recursive_dependencies).to have_same_ids_as(a_a_a, a_a, a).ordered
    end
  end
end
