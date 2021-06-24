# frozen_string_literal: true

require "webhookdb/service_integration"

RSpec.describe "Webhookdb::ServiceIntegration" do
  let(:described_class) { Webhookdb::ServiceIntegration }

  let!(:sint) { Webhookdb::Fixtures.service_integration.create }

  before(:each) do
    Webhookdb::Subscription.where(stripe_customer_id: sint.organization.stripe_customer_id).delete
  end

  describe "plan_supports_integration?" do
    it "returns true if the organization has an active subscription" do
      Webhookdb::Fixtures.subscription.active.for_org(sint.organization).create
      expect(sint.plan_supports_integration?).to eq(true)
    end
    it "returns true if the organization has no active subscription and sint is in first two integrations" do
      expect(sint.plan_supports_integration?).to eq(true)
    end
    it "returns false if the organization has no subscription and sint is not in first two integrations" do
      Webhookdb::Fixtures.subscription.canceled.for_org(sint.organization).create

      fake_twilio_sint = Webhookdb::ServiceIntegration.new(
        opaque_id: SecureRandom.hex(6),
        table_name: SecureRandom.hex(2),
        service_name: "twilio_sms_v1",
        organization: sint.organization,
      ).save_changes

      fake_shopify_sint = Webhookdb::ServiceIntegration.new(
        opaque_id: SecureRandom.hex(6),
        table_name: SecureRandom.hex(2),
        service_name: "shopify_order_v1",
        organization: sint.organization,
      ).save_changes

      expect(fake_twilio_sint.plan_supports_integration?).to eq(true)
      expect(fake_shopify_sint.plan_supports_integration?).to eq(false)
    end
  end
end