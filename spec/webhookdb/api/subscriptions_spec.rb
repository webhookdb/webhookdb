# frozen_string_literal: true

require "webhookdb/api/subscriptions"
require "webhookdb/admin_api/entities"

RSpec.describe Webhookdb::API::Subscriptions, :db do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }
  let!(:org) { Webhookdb::Fixtures.organization.create }
  let!(:customer) { Webhookdb::Fixtures.customer.in_org(org, verified: true).create }

  before(:each) do
    login_as(customer)
  end

  describe "GET /v1/organizations/:identifier/subscriptions/plans" do
    it "returns plans as a table" do
      stub_request(:get, "https://api.stripe.com/v1/prices?active=true").
        to_return(status: 200, body: load_fixture_data("stripe/prices_get", raw: true), headers: {})

      get "/v1/organizations/#{org.key}/subscriptions/plans"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        headers: [
          "key",
          "description",
          "price",
        ],
        rows: [
          [
            "monthly",
            "Monthly Subscription",
            "$89.00",
          ],
          [
            "yearly",
            "Yearly Subscription (2 months free)",
            "$890.00",
          ],
        ],
      )
    end

    it "returns plans as an object" do
      stub_request(:get, "https://api.stripe.com/v1/prices?active=true").
        to_return(status: 200, body: load_fixture_data("stripe/prices_get", raw: true), headers: {})

      get "/v1/organizations/#{org.key}/subscriptions/plans", fmt: "object"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        items: [include(description: "Monthly Subscription"), include(key: "yearly")],
      )
    end
  end

  describe "GET /v1/organizations/:identifier/subscriptions" do
    it "returns correct subscription information for free tier" do
      get "/v1/organizations/#{org.key}/subscriptions"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        org_name: org.name,
        billing_email: "",
        integrations_used: 0,
        plan_name: "Free",
        integrations_left: Webhookdb::Subscription.max_free_integrations,
      )
    end

    it "returns correct subscription information for premium tier" do
      org.update(billing_email: "santa@northpole.org")
      Webhookdb::Fixtures.subscription.active.for_org(org).create
      Webhookdb::Fixtures.service_integration.create(organization: org)

      get "/v1/organizations/#{org.key}/subscriptions"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        org_name: org.name,
        billing_email: "santa@northpole.org",
        integrations_used: 1,
        plan_name: "Premium",
        integrations_left: 2_000_000_000,
        integrations_left_display: "unlimited",
        sub_status: "active",
      )
    end
  end

  describe "POST /v1/organizations/:identifier/subscriptions/open_portal" do
    it "errors if org is not registered with stripe" do
      org.update(stripe_customer_id: "")
      post "/v1/organizations/#{org.key}/subscriptions/open_portal", plan: "yearly"

      expect(last_response).to have_status(409)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "This organization is not registered with Stripe."),
      )
    end

    it "prompts for an invalid plan" do
      req = stub_request(:get, "https://api.stripe.com/v1/prices?active=true").
        to_return(status: 200, body: load_fixture_data("stripe/prices_get", raw: true), headers: {})

      post "/v1/organizations/#{org.key}/subscriptions/open_portal", plan: "nope"

      expect(last_response).to have_status(422)
      expect(last_response).to have_json_body.
        that_includes(error: include(code: "prompt_required_params"))
      expect(req).to have_been_made
    end

    it "returns stripe checkout portal url if active subscription is not present" do
      prices_req = stub_request(:get, "https://api.stripe.com/v1/prices?active=true").
        to_return(status: 200, body: load_fixture_data("stripe/prices_get", raw: true), headers: {})

      session_req = stub_request(:post, "https://api.stripe.com/v1/checkout/sessions").
        to_return(
          status: 200,
          body: {url: "https://checkout.stripe.com/pay/cstest_foobar"}.to_json,
        )

      org.update(stripe_customer_id: "foobar")
      post "/v1/organizations/#{org.key}/subscriptions/open_portal", plan: "yearly"

      expect(prices_req).to have_been_made
      expect(session_req).to have_been_made
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(url: "https://checkout.stripe.com/pay/cstest_foobar")
    end

    it "returns stripe billing portal url if active subscription is present" do
      org.update(stripe_customer_id: "foobar")
      Webhookdb::Fixtures.subscription.active.for_org(org).create
      session_req = stub_request(:post, "https://api.stripe.com/v1/billing_portal/sessions").
        with(
          body: {"customer" => "foobar", "return_url" => "http://localhost:18002/jump/portal-return"},
        ).
        to_return(status: 200, body: {url: "https://billing.stripe.com/session/foobar"}.to_json)

      post "/v1/organizations/#{org.key}/subscriptions/open_portal"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(url: "https://billing.stripe.com/session/foobar")
      expect(session_req).to have_been_made
    end

    it "prompts the user for confirmation if a subscription is present, but a plan is passed" do
      org.update(stripe_customer_id: "foobar")
      Webhookdb::Fixtures.subscription.active.for_org(org).create

      post "/v1/organizations/#{org.key}/subscriptions/open_portal", plan: "monthly"

      expect(last_response).to have_status(422)
      expect(last_response.body).to include("You already have a subscription")
    end

    it "allows the user to confirm the 'subscription present' prompt" do
      org.update(stripe_customer_id: "foobar")
      Webhookdb::Fixtures.subscription.active.for_org(org).create

      session_req = stub_request(:post, "https://api.stripe.com/v1/billing_portal/sessions").
        to_return(status: 200, body: {url: "https://billing.stripe.com/session/foobar"}.to_json)

      post "/v1/organizations/#{org.key}/subscriptions/open_portal", plan: "monthly", guard_confirm: ""

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(:url)
      expect(session_req).to have_been_made
    end
  end
end
