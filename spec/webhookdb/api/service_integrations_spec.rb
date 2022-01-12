# frozen_string_literal: true

require "webhookdb/api/service_integrations"
require "webhookdb/admin_api/entities"
require "webhookdb/async"

RSpec.describe Webhookdb::API::ServiceIntegrations, :async, :db do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }
  let!(:org) { Webhookdb::Fixtures.organization.create }
  let!(:customer) { Webhookdb::Fixtures.customer.in_org(org, verified: true).create }
  let!(:sint) do
    Webhookdb::Fixtures.service_integration.create(
      opaque_id: "xyz",
      organization: org,
      service_name: "fake_v1",
      backfill_key: "qwerty",
    )
  end
  let!(:admin_role) { Webhookdb::Role.create(name: "admin") }

  before(:each) do
    Webhookdb::Services::Fake.reset
    login_as(customer)
  end

  after(:each) do
    Webhookdb::Services::Fake.reset
  end

  def max_out_plan_integrations(org)
    # Already have an initial service integration, create one more, then a 3rd which won't be usable
    Webhookdb::Fixtures.service_integration(organization: org).create
    return Webhookdb::Fixtures.service_integration(organization: org).create
  end

  describe "GET v1/organizations/:org_identifier/service_integrations" do
    let(:blank_org) { Webhookdb::Fixtures.organization.create } # create org without any integrations attached
    let(:membership) { blank_org.add_membership(customer:, verified: true) }

    it "returns all service integrations associated with organization" do
      # add new integration to ensure that the endpoint can return multiple integrations
      new_integration = Webhookdb::Fixtures.service_integration.create(organization: org)
      # add extra integration to ensure that the endpoint filters out integrations from other orgs
      _extra_integration = Webhookdb::Fixtures.service_integration.create

      get "/v1/organizations/#{org.key}/service_integrations"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(items: have_same_ids_as([sint, new_integration]).pk_field(:opaque_id))
    end

    it "returns a message if org has no service integrations" do
      sint.destroy

      get "/v1/organizations/#{org.key}/service_integrations"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(message: "Organization doesn't have any integrations yet.")
    end
  end

  describe "POST v1/organizations/:org_identifier/service_integrations/create" do
    let(:internal_role) { Webhookdb::Role.create(name: "internal") }

    it "creates a service integration" do
      customer.memberships_dataset.update(membership_role_id: admin_role.id)
      org.add_feature_role(internal_role)

      post "/v1/organizations/#{org.key}/service_integrations/create", service_name: "fake_v1"

      new_integration = Webhookdb::ServiceIntegration.where(service_name: "fake_v1", organization: org).first
      expect(new_integration).to_not be_nil
    end

    it "returns a state machine step" do
      customer.memberships_dataset.update(membership_role_id: admin_role.id)
      org.add_feature_role(internal_role)

      post "/v1/organizations/#{org.key}/service_integrations/create", service_name: "fake_v1"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        needs_input: true,
        output: "You're creating a fake_v1 service integration.",
        prompt: "Paste or type your fake API secret here:",
        prompt_is_secret: false, post_to_url: match("/transition/webhook_secret"), complete: false,
      )
    end

    it "fails if the current user is not an admin" do
      post "/v1/organizations/#{org.key}/service_integrations/create", service_name: "fake_v1"

      # expect(last_response).to have_status(400)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "Permission denied: You don't have admin privileges with #{org.name}."),
      )
    end

    it "fails if creating the service integration requires a subscription" do
      org.add_feature_role(internal_role)

      _twilio_sint = Webhookdb::ServiceIntegration.new(
        opaque_id: SecureRandom.hex(6),
        table_name: SecureRandom.hex(2),
        service_name: "twilio_sms_v1",
        organization: org,
      ).save_changes

      _shopify_sint = Webhookdb::ServiceIntegration.new(
        opaque_id: SecureRandom.hex(6),
        table_name: SecureRandom.hex(2),
        service_name: "shopify_order_v1",
        organization: org,
      ).save_changes

      post "/v1/organizations/#{org.key}/service_integrations/create", service_name: "fake_v1"

      expect(last_response).to have_status(402)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "You have reached the maximum number of free integrations"),
      )
    end

    it "returns a state machine step if org does not have required feature role access" do
      customer.memberships_dataset.update(membership_role_id: admin_role.id)
      post "/v1/organizations/#{org.key}/service_integrations/create", service_name: "fake_v1"

      available_services = org.available_services.join("\n\t")
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        needs_input: false,
        output: match("you currently have access to:\n\n\t#{available_services}"),
        complete: true,
      )
    end

    it "returns a state machine step if the given service name is not valid" do
      customer.memberships_dataset.update(membership_role_id: admin_role.id)
      org.add_feature_role(internal_role)

      post "/v1/organizations/#{org.key}/service_integrations/create", service_name: "faake_v1"

      available_services = org.available_services.join("\n\t")
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        needs_input: false,
        output: match("currently supported by WebhookDB:\n\n\t#{available_services}"),
        complete: true,
      )
    end
  end

  describe "POST /v1/organizations/:org_identifier/service_integrations/:opaque_id" do
    before(:each) do
      # this endpoint should be unauthed, so we will test it unauthed
      logout
    end

    it "publishes an event with the data for the webhook", :async do
      header "X-My-Test", "abc"
      expect do
        post "/v1/organizations/#{org.key}/service_integrations/xyz", foo: 1
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
      post "/v1/organizations/#{org.key}/service_integrations/xyz"

      expect(last_response).to have_status(202)
      expect(last_response.body).to eq("ok")
      expect(last_response.headers).to include("Content-Type" => "text/plain")
    end

    it "returns the response from the configured service" do
      Webhookdb::Services::Fake.webhook_response = [203, {"Content-Type" => "text/xml"}, "<x></x>"]

      post "/v1/organizations/#{org.key}/service_integrations/xyz"

      expect(last_response).to have_status(203)
      expect(last_response.body).to eq("<x></x>")
      expect(last_response.headers).to include("Content-Type" => "text/xml")
    end

    it "400s if there is no active service integration" do
      sint.soft_delete
      header "X-My-Test", "abc"
      post "/v1/organizations/#{org.key}/service_integrations/xyz", foo: 1
      expect(last_response).to have_status(400)
    end

    it "does not publish if the webhook fails verification", :async do
      Webhookdb::Services::Fake.webhook_verified = false

      expect do
        post "/v1/organizations/#{org.key}/service_integrations/xyz"
        expect(last_response).to have_status(401)
      end.to_not publish("webhookdb.serviceintegration.webhook")
    end

    it "db logs on success" do
      post "/v1/organizations/#{org.key}/service_integrations/xyz", a: 1
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
      post "/v1/organizations/#{org.key}/service_integrations/abc"
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
      post "/v1/organizations/#{org.key}/service_integrations/xyz"
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
      post "/v1/organizations/#{org.key}/service_integrations/xyz"
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

  describe "POST /v1/organizations/:org_identifier/service_integrations/:opaque_id/reset" do
    before(:each) do
      login_as(customer)
    end

    it "clears the webhook setup information" do
      sint.update(webhook_secret: "whsek")
      post "/v1/organizations/#{org.key}/service_integrations/xyz/reset"
      sint = Webhookdb::ServiceIntegration[opaque_id: "xyz"]
      expect(sint).to have_attributes(webhook_secret: "")
    end

    it "returns a state machine step" do
      post "/v1/organizations/#{org.key}/service_integrations/xyz/reset"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        needs_input: true,
        output: "You're creating a fake_v1 service integration.",
        prompt: "Paste or type your fake API secret here:",
        prompt_is_secret: false, post_to_url: match("/transition/webhook_secret"), complete: false,
      )
    end

    it "fails if service integration is not supported by subscription plan" do
      maxed = max_out_plan_integrations(org)

      post "/v1/organizations/#{org.key}/service_integrations/#{maxed.opaque_id}/reset"

      expect(last_response).to have_status(402)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "Integration no longer supported--please visit website to activate subscription."),
      )
    end
  end

  describe "POST /v1/organizations/:org_identifier/service_integrations/:opaque_id/backfill" do
    before(:each) do
      login_as(customer)
    end

    it "returns a state machine step" do
      post "/v1/organizations/#{org.key}/service_integrations/xyz/backfill"

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
        post "/v1/organizations/#{org.key}/service_integrations/xyz/backfill"
      end.to publish("webhookdb.serviceintegration.backfill").with_payload([sint.id])
    end

    it "fails if service integration is not supported by subscription plan" do
      maxed = max_out_plan_integrations(org)

      post "/v1/organizations/#{org.key}/service_integrations/#{maxed.opaque_id}/backfill"

      expect(last_response).to have_status(402)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "Integration no longer supported--please visit website to activate subscription."),
      )
    end
  end

  describe "POST /v1/organizations/:org_identifier/service_integrations/:opaque_id/backfill/reset" do
    before(:each) do
      login_as(customer)
    end

    it "clears the backfill information" do
      sint.update(api_url: "example.api.com", backfill_key: "bf_key", backfill_secret: "bf_sek")
      post "/v1/organizations/#{org.key}/service_integrations/xyz/backfill/reset"
      sint = Webhookdb::ServiceIntegration[opaque_id: "xyz"]
      expect(sint).to have_attributes(api_url: "")
      expect(sint).to have_attributes(backfill_key: "")
      expect(sint).to have_attributes(backfill_secret: "")
    end

    it "returns a state machine step" do
      post "/v1/organizations/#{org.key}/service_integrations/xyz/backfill/reset"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        needs_input: true,
        output: "Now let's test the backfill flow.", prompt: "Paste or type a string here:",
        prompt_is_secret: false, post_to_url: match("/transition/backfill_secret"), complete: false,
      )
    end

    it "fails if service integration is not supported by subscription plan" do
      maxed = max_out_plan_integrations(org)

      post "/v1/organizations/#{org.key}/service_integrations/#{maxed.opaque_id}/backfill/reset"

      expect(last_response).to have_status(402)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "Integration no longer supported--please visit website to activate subscription."),
      )
    end
  end

  describe "POST /v1/organizations/:org_identifier/service_integrations/:opaque_id/transition/:field" do
    before(:each) do
      login_as(customer)
    end

    it "calls the state machine with the given field and value and returns the result" do
      post "/v1/organizations/#{org.key}/service_integrations/xyz/transition/webhook_secret", value: "open sesame"

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

    it "403s if the current user cannot modify the integration due to org permissions" do
      new_sint = Webhookdb::Fixtures.service_integration.create(opaque_id: "abc") # create sint outside the customer org

      post "/v1/organizations/#{new_sint.organization.key}/service_integrations/abc/transition/field_name",
           value: "open sesame"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "You don't have permissions with that organization."),
      )
    end

    it "fails if service integration is not supported by subscription plan" do
      maxed = max_out_plan_integrations(org)

      post "/v1/organizations/#{org.key}/service_integrations/#{maxed.opaque_id}/transition/webhook_secret",
           value: "open_sesame"

      expect(last_response).to have_status(402)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "Integration no longer supported--please visit website to activate subscription."),
      )
    end
  end
end
