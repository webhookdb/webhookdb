# frozen_string_literal: true

require "webhookdb/subscription"

RSpec.describe "Webhookdb::Subscription", :db do
  let(:described_class) { Webhookdb::Subscription }

  it "can find its organization" do
    sub = Webhookdb::Fixtures.subscription.create(stripe_customer_id: "sub_abc")
    expect(sub).to have_attributes(organization: nil)
    org = Webhookdb::Fixtures.organization.create(stripe_customer_id: "sub_xyz")
    expect(org.subscription).to be_nil
    expect(sub.refresh.organization).to be_nil

    org.update(stripe_customer_id: "sub_abc")
    expect(org.refresh).to have_attributes(subscription: be === sub)
    expect(sub.refresh).to have_attributes(organization: be === org)
  end

  describe "list_plans" do
    it "lists plans" do
      req = stub_request(:get, "https://api.stripe.com/v1/prices?active=true").
        to_return(status: 200, body: load_fixture_data("stripe/prices_get", raw: true), headers: {})

      plans = described_class.list_plans
      expect(plans.as_json).to match_array(
        [
          {description: "Monthly Subscription", key: "monthly", price: cost("$89")},
          {description: "Yearly Subscription (2 months free)", key: "yearly", price: cost("$890")},
        ],
      )

      expect(req).to have_been_made
    end
  end

  describe "create_or_update" do
    describe "create_or_update_from_stripe_hash", async: true do
      let(:stripe_data) { load_fixture_data("stripe/subscription_get") }

      it "creates a subscription for a given org if one doesn't exist" do
        org = Webhookdb::Fixtures.organization.create(stripe_customer_id: "cus_JR8V3eF6JmvjKZ")
        Webhookdb::Subscription.create_or_update_from_stripe_hash(stripe_data)

        sub = Webhookdb::Subscription[stripe_id: "sub_JigYoW2aRYfl0R"]
        expect(sub).to have_attributes(
          stripe_customer_id: "cus_JR8V3eF6JmvjKZ",
          stripe_id: "sub_JigYoW2aRYfl0R",
          stripe_json: include("status"),
          organization: be == org,
        )
      end

      it "updates the subscription status of an existing subscription" do
        sub = Webhookdb::Fixtures.subscription.create(stripe_id: "sub_JigYoW2aRYfl0R")
        Webhookdb::Subscription.create_or_update_from_stripe_hash(stripe_data)

        expect(Webhookdb::Subscription.all).to contain_exactly(be === sub)
        sub.refresh
        expect(sub.stripe_customer_id).to eq("cus_JR8V3eF6JmvjKZ")
        expect(sub.stripe_json).to have_key("status")
      end

      it "emits a developer alert when a subscription is created" do
        Webhookdb::Fixtures.organization.create(stripe_customer_id: "cus_JR8V3eF6JmvjKZ")
        expect do
          Webhookdb::Subscription.create_or_update_from_stripe_hash(stripe_data)
        end.to publish("webhookdb.developeralert.emitted").with_payload(
          match_array([include("subsystem" => "Subscription Created")]),
        )
      end

      it "emit a developer alert if there is no matching organization" do
        expect do
          Webhookdb::Subscription.create_or_update_from_stripe_hash(stripe_data)
        end.to publish("webhookdb.developeralert.emitted").with_payload(
          match_array([include("subsystem" => "Subscription Error")]),
        )
      end

      it "emits a developer alert if the subscription status changes" do
        Webhookdb::Fixtures.organization.create(stripe_customer_id: "cus_JR8V3eF6JmvjKZ")
        Webhookdb::Subscription.create_or_update_from_stripe_hash(stripe_data)

        stripe_data["status"] = "trialing"
        expect do
          Webhookdb::Subscription.create_or_update_from_stripe_hash(stripe_data)
        end.to publish("webhookdb.developeralert.emitted").with_payload(
          match_array([include("subsystem" => "Subscription Status Change")]),
        )

        # No alert for other field type
        stripe_data["cancel_at_period_end"] = true
        expect do
          Webhookdb::Subscription.create_or_update_from_stripe_hash(stripe_data)
        end.to_not publish("webhookdb.developeralert.emitted")
      end
    end

    describe "create_or_update_from_webhook" do
      it "creates/updates a subscription for a given org" do
        Webhookdb::Subscription.create_or_update_from_webhook(load_fixture_data("stripe/subscription_webhook"))

        sub = Webhookdb::Subscription[stripe_id: "sub_JigYoW2aRYfl0R"]
        expect(sub).to_not be_nil
        expect(sub.stripe_customer_id).to eq("cus_JR8V3eF6JmvjKZ")
        expect(sub.stripe_json).to have_key("status")
      end
    end

    describe "create_or_update_from_id" do
      it "creates/updates the subscription with the given id" do
        req = stub_request(:get, "https://api.stripe.com/v1/subscriptions/sub_JigYoW2aRYfl0R").
          to_return(body: load_fixture_data("stripe/subscription_get", raw: true))
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
    let!(:org) { Webhookdb::Fixtures.organization(name: "My Org").create }
    let!(:test_delete) { Webhookdb::Fixtures.organization.create }

    it "returns correct information if subscription does not exist" do
      status = described_class.status_for_org(org)
      expect(status.as_json).to include(
        organization_name: org.name,
        organization_key: org.key,
        billing_email: "",
        integrations_used: 0,
        plan_name: "Free",
        integrations_remaining: 2,
        integrations_remaining_formatted: "2",
        sub_status: "",
      )
      expect(status.display_headers.map { |k, f| [f, status.data[k]] }).to match_array(
        [
          ["Organization", "My Org (my_org)"],
          ["Billing email", ""],
          ["Plan name", "Free"],
          ["Integrations used", "0"],
          ["Integrations left", "2"],
          ["Status", ""],
        ],
      )
    end

    it "returns correct information if subscription exists" do
      org.update(billing_email: "santa@northpole.org")
      Webhookdb::Fixtures.subscription.active.for_org(org).create
      Webhookdb::Fixtures.service_integration.create(organization: org)
      Webhookdb::Fixtures.service_integration.create(organization: test_delete)
      Webhookdb::Fixtures.service_integration.soft_delete

      status = described_class.status_for_org(org)
      expect(status.as_json).to include(
        organization_name: org.name,
        organization_key: org.key,
        billing_email: "santa@northpole.org",
        integrations_used: 1,
        plan_name: "fixtured plan",
        integrations_remaining: 2_000_000_000,
        integrations_remaining_formatted: "unlimited",
        sub_status: "active",
      )
      expect(status.display_headers.map { |k, f| [f, status.data[k]] }).to match_array(
        [
          ["Organization", "My Org (my_org)"],
          ["Billing email", "santa@northpole.org"],
          ["Plan name", "fixtured plan"],
          ["Integrations used", "1"],
          ["Integrations left", "unlimited"],
          ["Status", "active"],
        ],
      )
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
