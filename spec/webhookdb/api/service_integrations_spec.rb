# frozen_string_literal: true

require "webhookdb/api/service_integrations"
require "webhookdb/admin_api/entities"
require "webhookdb/async"

RSpec.describe Webhookdb::API::ServiceIntegrations, :async, :db do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }
  let!(:customer) { Webhookdb::Fixtures.customer.create }
  let!(:org) { Webhookdb::Fixtures.organization.create }
  let!(:membership) { org.add_membership(customer: customer, verified: true) }
  let!(:admin_role) { Webhookdb::OrganizationRole.create(name: "admin") }
  let!(:sint) do
    Webhookdb::Fixtures.service_integration.create(opaque_id: "xyz", organization: org, service_name: "fake_v1",
                                                   backfill_key: "qwerty",)
  end

  let!(:twilio_sint) do
    Webhookdb::ServiceIntegration.create(
      {
        opaque_id: SecureRandom.hex(6),
        table_name: SecureRandom.hex(2),
        service_name: "twilio_sms_v1",
        organization: org,
      },
    )
  end

  let!(:shopify_sint) do
    Webhookdb::ServiceIntegration.create(
      {
        opaque_id: SecureRandom.hex(6),
        table_name: SecureRandom.hex(2),
        service_name: "shopify_order_v1",
        organization: org,
      },
    )
  end
  before(:all) do
    Webhookdb::Async.require_jobs
  end

  after(:each) do
    Webhookdb::Services::Fake.reset
  end

  let!(:organization) { Webhookdb::Fixtures.organization.create }

  describe "POST /v1/service_integrations/:opaque_id" do
    before(:each) do
      Webhookdb::Services::Fake.reset
    end

    it "publishes an event with the data for the webhook", :async do
      header "X-My-Test", "abc"
      expect do
        post "/v1/service_integrations/xyz", foo: 1
        expect(last_response).to have_status(202)
      end.to publish("webhookdb.serviceintegration.webhook").with_payload(
        match_array(
          [
            sint.id,
            hash_including(
              "headers" => hash_including("X-My-Test" => "abc"),
              "body" => {"foo" => 1},
            ),
          ],
        ),
      )
    end

    it "handles default response behavior" do
      post "/v1/service_integrations/xyz"

      expect(last_response).to have_status(202)
      expect(last_response.body).to eq("ok")
      expect(last_response.headers).to include("Content-Type" => "text/plain")
    end

    it "returns the response from the configured service" do
      Webhookdb::Services::Fake.webhook_response = [203, {"Content-Type" => "text/xml"}, "<x></x>"]

      post "/v1/service_integrations/xyz"

      expect(last_response).to have_status(203)
      expect(last_response.body).to eq("<x></x>")
      expect(last_response.headers).to include("Content-Type" => "text/xml")
    end

    it "400s if there is no active service integration" do
      sint.soft_delete
      header "X-My-Test", "abc"
      post "/v1/service_integrations/xyz", foo: 1
      expect(last_response).to have_status(400)
    end

    it "does not publish if the webhook fails verification", :async do
      Webhookdb::Services::Fake.webhook_verified = false

      expect do
        post "/v1/service_integrations/xyz"
        expect(last_response).to have_status(401)
      end.to_not publish("webhookdb.serviceintegration.webhook")
    end
  end

  describe "POST /v1/service_integrations/:opaque_id/backfill" do
    before(:each) do
      Webhookdb::Services::Fake.reset
      login_as(customer)
    end

    it "returns a state machine step" do
      post "/v1/service_integrations/xyz/backfill"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        needs_input: true,
        output: "Now let's test the backfill flow.", prompt: "Paste or type a string here:",
        prompt_is_secret: false, post_to_url: match("/transition/backfill_secret"), complete: false,
      )
    end

    it "starts backfill process if setup is complete" do
      Webhookdb::Services::Fake.backfill_responses = {
        nil => [[], nil],
      }

      expect do
        post "/v1/service_integrations/xyz/backfill"
      end.to perform_async_job(Webhookdb::Jobs::Backfill)
    end

    it "fails if service integration is not supported by subscription plan" do
      post "/v1/service_integrations/#{shopify_sint.opaque_id}/backfill"

      expect(last_response).to have_status(402)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "Integration no longer supported--please visit website to activate subscription."),
      )
    end
  end

  describe "POST /v1/service_integrations/:opaque_id/transition/:field" do
    before(:each) do
      Webhookdb::Services::Fake.reset
      login_as(customer)
    end

    it "calls the state machine with the given field and value and returns the result" do
      post "/v1/service_integrations/xyz/transition/webhook_secret", value: "open sesame"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        needs_input: false, prompt: nil, prompt_is_secret: nil,
        post_to_url: nil, complete: true,
        output: match("The integration creation flow is working correctly"),
      )
    end

    it "403s if the current user cannot modify the integration" do
      Webhookdb::Fixtures.service_integration.create(opaque_id: "abc") # create sint outside the customer org

      post "/v1/service_integrations/abc/transition/field_name", value: "open sesame"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "Sorry, you cannot modify this integration."),
      )
    end

    it "fails if service integration is not supported by subscription plan" do
      post "/v1/service_integrations/#{shopify_sint.opaque_id}/transition/webhook_secret", value: "open_sesame"

      expect(last_response).to have_status(402)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "Integration no longer supported--please visit website to activate subscription."),
      )
    end
  end
end
