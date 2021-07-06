# frozen_string_literal: true

require "webhookdb/api/subscriptions"
require "webhookdb/admin_api/entities"

RSpec.describe Webhookdb::API::Subscriptions, :db do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }
  let!(:customer) { Webhookdb::Fixtures.customer.create }
  let!(:org) { Webhookdb::Fixtures.organization.create }
  let!(:membership) { org.add_membership(customer: customer, verified: true) }

  before(:each) do
    login_as(customer)
  end

  describe "GET /v1/subscription" do
    it "returns correct subscription information for free tier" do
      get "/v1/subscription", identifier: org.key

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        org_name: org.name,
        billing_email: "",
        integrations_used: 0,
        plan_name: "Free",
        integrations_left: 2,
      )
    end

    it "returns correct subscription information for premium tier" do
      org.update(billing_email: "santa@northpole.org")
      Webhookdb::Fixtures.subscription.active.for_org(org).create
      Webhookdb::Fixtures.service_integration.create(organization: org)

      get "/v1/subscription", identifier: org.key

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        org_name: org.name,
        billing_email: "santa@northpole.org",
        integrations_used: 1,
        plan_name: "Premium",
        integrations_left: "unlimited",
        sub_status: "active",
      )
    end
  end

  describe "POST /v1/subscription/open_portal" do
    it "errors if org is not registered with stripe" do
      org.update(stripe_customer_id: "")
      post "/v1/subscription/open_portal", identifier: org.key

      expect(last_response).to have_status(409)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "This organization is not registered with Stripe."),
      )
    end

    it "redirects to stripe portal" do
      req = stub_request(:post, "https://api.stripe.com/v1/billing_portal/sessions").
        with(
          body: {"customer" => "foobar", "return_url" => "http://localhost:17001/v1/subscriptions/portal_return"},
          headers: {
            "Accept" => "*/*",
            "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
            "Authorization" => "Bearer lithic_stripe_api_key",
            "Content-Type" => "application/x-www-form-urlencoded",
            "User-Agent" => "Stripe/v1 RubyBindings/5.32.1",
          },
        ).
        to_return(
          status: 200,
          body: {
            url: "https://billing.stripe.com/session/foobar",
          }.to_json,
        )

      org.update(stripe_customer_id: "foobar")
      post "/v1/subscription/open_portal", identifier: org.key

      expect(req).to have_been_made
      expect(last_response).to have_status(302)
      expect(last_response.body).to match("Redirecting you to Stripe...")
    end
  end

  describe "POST v1/subscriptions" do
    it "returns an html page with the right message" do
      post "/v1/subscription/portal_return"

      expect(last_response).to have_status(200)
      expect(last_response.body).to include("You have sucessfully viewed or updated your Stripe Billing Information.")
    end
  end
end
