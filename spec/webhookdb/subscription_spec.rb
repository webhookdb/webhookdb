# frozen_string_literal: true

require "webhookdb/subscription"

RSpec.describe "Webhookdb::Subscription", :db do
  let(:described_class) { Webhookdb::Subscription }

  describe "create_or_update" do
    describe "create_or_update_from_webhook" do
      it "creates a subscription for a given org if one doesn't exist" do
        Webhookdb::Subscription.create_or_update_from_webhook(load_fixture_data("stripe/subscription_webhook"))

        sub = Webhookdb::Subscription[stripe_id: "sub_JigYoW2aRYfl0R"]
        expect(sub).to_not be_nil
        expect(sub.stripe_customer_id).to eq("cus_JR8V3eF6JmvjKZ")
        expect(sub.stripe_json).to have_key("status")
      end

      it "updates the subscription status of an existing subscription" do
        Webhookdb::Fixtures.subscription.create(stripe_id: "sub_JigYoW2aRYfl0R")
        Webhookdb::Subscription.create_or_update_from_webhook(load_fixture_data("stripe/subscription_webhook"))

        sub = Webhookdb::Subscription[stripe_id: "sub_JigYoW2aRYfl0R"]
        expect(sub).to_not be_nil
        expect(sub.stripe_customer_id).to eq("cus_JR8V3eF6JmvjKZ")
        expect(sub.stripe_json).to have_key("status")
      end
    end

    describe "create_or_update_from_id" do
      it "creates a subscription for a given org if one doesn't exist" do
        req = stub_request(:get, "https://api.stripe.com/v1/subscriptions/sub_JigYoW2aRYfl0R").
          to_return(body: load_fixture_data("stripe/subscription_get", raw: true))
        Webhookdb::Subscription.create_or_update_from_id("sub_JigYoW2aRYfl0R")

        expect(req).to have_been_made
        sub = Webhookdb::Subscription[stripe_id: "sub_JigYoW2aRYfl0R"]
        expect(sub).to_not be_nil
        expect(sub.stripe_customer_id).to eq("cus_JR8V3eF6JmvjKZ")
        expect(sub.stripe_json).to have_key("status")
      end

      it "updates the subscription status of an existing subscription" do
        req = stub_request(:get, "https://api.stripe.com/v1/subscriptions/sub_JigYoW2aRYfl0R").
          to_return(body: load_fixture_data("stripe/subscription_get", raw: true))
        Webhookdb::Fixtures.subscription.create(stripe_id: "sub_JigYoW2aRYfl0R")
        Webhookdb::Subscription.create_or_update_from_id("sub_JigYoW2aRYfl0R")

        expect(req).to have_been_made
        sub = Webhookdb::Subscription[stripe_id: "sub_JigYoW2aRYfl0R"]
        expect(sub).to_not be_nil
        expect(sub.stripe_customer_id).to eq("cus_JR8V3eF6JmvjKZ")
        expect(sub.stripe_json).to have_key("status")
      end
    end
  end

  describe "status_for_org" do
    let!(:org) { Webhookdb::Fixtures.organization.create }

    it "returns correct information if subscription does not exist" do
      data = Webhookdb::Subscription.status_for_org(org)

      expect(data[:org_name]).to eq(org.name)
      expect(data[:billing_email]).to eq("")
      expect(data[:integrations_used]).to eq(0)
      expect(data[:plan_name]).to eq("Free")
      expect(data[:integrations_left]).to eq(Webhookdb::Subscription.max_free_integrations)
      expect(data[:integrations_left_display]).to eq(Webhookdb::Subscription.max_free_integrations.to_s)
      expect(data[:sub_status]).to eq("")
    end

    it "returns correct information if subscription exists" do
      org.update(billing_email: "santa@northpole.org")
      Webhookdb::Fixtures.subscription.active.for_org(org).create
      Webhookdb::Fixtures.service_integration.create(organization: org)

      data = Webhookdb::Subscription.status_for_org(org)
      expect(data[:org_name]).to eq(org.name)
      expect(data[:billing_email]).to eq("santa@northpole.org")
      expect(data[:integrations_used]).to eq(1)
      expect(data[:plan_name]).to eq("Premium")
      expect(data[:integrations_left]).to eq(2_000_000_000)
      expect(data[:integrations_left_display]).to eq("unlimited")
      expect(data[:sub_status]).to eq("active")
    end
  end

  describe "backfill_from_stripe" do
    it "requests a single page by default" do
      req = stub_request(:get, "https://api.stripe.com/v1/subscriptions?limit=20").
        to_return(body: load_fixture_data("stripe/subscription_list", raw: true))

      expect(Webhookdb::Subscription.all).to be_empty
      described_class.backfill_from_stripe(page_size: 20)
      expect(req).to have_been_made
      expect(Webhookdb::Subscription.all).to have_length(2)
    end

    it "processes up to limit" do
      req = stub_request(:get, "https://api.stripe.com/v1/subscriptions?limit=50").
        to_return(body: load_fixture_data("stripe/subscription_list", raw: true))

      expect(Webhookdb::Subscription.all).to be_empty
      described_class.backfill_from_stripe(limit: 1)
      expect(req).to have_been_made
      expect(Webhookdb::Subscription.all).to have_length(1)
    end
  end
end
