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
  let!(:admin_role) { Webhookdb::Role.create(name: "admin") }
  let!(:sint) do
    Webhookdb::Fixtures.service_integration.create(
      opaque_id: "xyz", organization: org, service_name: "fake_v1", backfill_key: "qwerty",
    )
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

    it "db logs on success" do
      post "/v1/service_integrations/xyz", a: 1
      expect(last_response).to have_status(202)
      expect(Webhookdb::LoggedWebhook.naked.all).to contain_exactly(
        include(
          inserted_at: match_time(Time.now).within(5),
          organization_id: sint.organization_id,
          request_body: '{"a":1}',
          request_headers: hash_including("Host" => "example.org"),
          response_status: 202,
          service_integration_opaque_id: "xyz",
        ),
      )
    end

    it "db logs on lookup and other errors" do
      post "/v1/service_integrations/abc"
      expect(last_response).to have_status(400)
      expect(Webhookdb::LoggedWebhook.naked.all).to contain_exactly(
        include(
          organization_id: nil,
          response_status: 400,
          service_integration_opaque_id: "abc",
        ),
      )
    end

    it "db logs on failed validation" do
      Webhookdb::Services::Fake.webhook_verified = false
      post "/v1/service_integrations/xyz"
      expect(last_response).to have_status(401)
      expect(Webhookdb::LoggedWebhook.naked.all).to contain_exactly(
        include(
          organization_id: sint.organization_id,
          response_status: 401,
          service_integration_opaque_id: "xyz",
        ),
      )
    end

    it "db logs on exception" do
      Webhookdb::Services::Fake.webhook_verified = RuntimeError.new("foo")
      post "/v1/service_integrations/xyz"
      expect(last_response).to have_status(500)
      expect(Webhookdb::LoggedWebhook.naked.all).to contain_exactly(
        include(
          organization_id: sint.organization_id,
          response_status: 0,
          service_integration_opaque_id: "xyz",
        ),
      )
    end
  end

  describe "POST /v1/service_integrations/:opaque_id/reset" do
    before(:each) do
      login_as(customer)
    end

    it "clears the webhook setup information" do
      sint.update(webhook_secret: "whsek")
      post "/v1/service_integrations/xyz/reset"
      sint = Webhookdb::ServiceIntegration[opaque_id: "xyz"]
      expect(sint).to have_attributes(webhook_secret: "")
    end

    it "returns a state machine step" do
      post "/v1/service_integrations/xyz/reset"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        needs_input: true,
        output: "You're creating a fake_v1 service integration.",
        prompt: "Paste or type your fake API secret here:",
        prompt_is_secret: false, post_to_url: match("/transition/webhook_secret"), complete: false,
      )
    end

    it "fails if service integration is not supported by subscription plan" do
      post "/v1/service_integrations/#{shopify_sint.opaque_id}/reset"

      expect(last_response).to have_status(402)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "Integration no longer supported--please visit website to activate subscription."),
      )
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

    it "starts backfill process if setup is complete", :async do
      sint.update(backfill_secret: "sek")
      expect do
        post "/v1/service_integrations/xyz/backfill"
      end.to publish("webhookdb.serviceintegration.backfill").with_payload([sint.id])
    end

    it "fails if service integration is not supported by subscription plan" do
      post "/v1/service_integrations/#{shopify_sint.opaque_id}/backfill"

      expect(last_response).to have_status(402)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "Integration no longer supported--please visit website to activate subscription."),
      )
    end
  end

  describe "POST /v1/service_integrations/:opaque_id/backfill/reset" do
    before(:each) do
      Webhookdb::Services::Fake.reset
      login_as(customer)
    end

    it "clears the backfill information" do
      sint.update(api_url: "example.api.com", backfill_key: "bf_key", backfill_secret: "bf_sek")
      post "/v1/service_integrations/xyz/backfill/reset"
      sint = Webhookdb::ServiceIntegration[opaque_id: "xyz"]
      expect(sint).to have_attributes(api_url: "")
      expect(sint).to have_attributes(backfill_key: "")
      expect(sint).to have_attributes(backfill_secret: "")
    end

    it "returns a state machine step" do
      post "/v1/service_integrations/xyz/backfill/reset"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        needs_input: true,
        output: "Now let's test the backfill flow.", prompt: "Paste or type a string here:",
        prompt_is_secret: false, post_to_url: match("/transition/backfill_secret"), complete: false,
      )
    end

    it "fails if service integration is not supported by subscription plan" do
      post "/v1/service_integrations/#{shopify_sint.opaque_id}/backfill/reset"

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
        needs_input: false,
        prompt: false,
        prompt_is_secret: false,
        post_to_url: "",
        complete: true,
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
