# frozen_string_literal: true

require "webhookdb/service_integration"

RSpec.describe "Webhookdb::ServiceIntegration", :db do
  let(:described_class) { Webhookdb::ServiceIntegration }

  let!(:sint) { Webhookdb::Fixtures.service_integration.create }

  before(:each) do
    Webhookdb::Subscription.where(stripe_customer_id: sint.organization.stripe_customer_id).delete
  end

  describe "all_webhook_subs" do
    it "returns the webhook subs associated with both the integration and the org" do
      Webhookdb::Fixtures.webhook_subscription.create(service_integration: sint)
      Webhookdb::Fixtures.webhook_subscription.create(organization: sint.organization)

      expect(sint.all_webhook_subs).to have_length(2)
    end
  end

  describe "plan_supports_integration?" do
    it "returns true if the organization has an active subscription" do
      Webhookdb::Fixtures.subscription.active.for_org(sint.organization).create
      expect(sint.plan_supports_integration?).to eq(true)
    end

    it "returns true if the organization has no active subscription and sint is in first integrations" do
      expect(sint.plan_supports_integration?).to eq(true)
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

      expect(twilio_sint.plan_supports_integration?).to eq(true)
      expect(shopify_sint.plan_supports_integration?).to eq(false)
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

    it "returns information in 'table' format" do
      expect(sint.stats("table")).to include(
        headers: ["name", "value"],
        rows: match_array(
          [
            ["Total Webhooks Logged", 4],
            ["Successful Webhooks", 3],
            ["Percent Successful", "75.0%"],
            ["Rejected Webhooks", 1],
            ["Percent Rejected", "25.0%"],
          ],
        ),
      )
    end

    it "returns information as an object" do
      expect(sint.stats("object")).to include(
        total_count: 4,
        rejected_count: 1,
        success_count: 3,
        rejected_percent: "25.0%",
        success_percent: "75.0%",
      )
    end

    it "raises ArgumentError if format parameter is invalid" do
      expect { sint.stats("wrong") }.to raise_error(ArgumentError, "\"wrong\" is not a valid format for webhook stats")
    end
  end
end
