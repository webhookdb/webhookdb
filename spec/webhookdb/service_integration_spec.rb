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

      expect(sint.all_webhook_subscriptions).to have_same_ids_as(sint_sub, org_sub)
    end
  end

  describe "plan_supports_integration?" do
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
      sint.service_instance.create_table
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
      end.to raise_error(described_class::TableRenameError, /must start with a letter/)
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
end
