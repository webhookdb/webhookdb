# frozen_string_literal: true

require "webhookdb/api/service_integrations"
require "webhookdb/admin_api/entities"
require "webhookdb/async"

RSpec.describe Webhookdb::API::ServiceIntegrations, :async, :db, :fake_replicator do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }
  let!(:org) { Webhookdb::Fixtures.organization.create }
  let!(:customer) { Webhookdb::Fixtures.customer.create }
  let!(:membership) { Webhookdb::Fixtures.organization_membership(organization: org, customer:).verified.create }
  let(:sint) do
    Webhookdb::Fixtures.service_integration.create(
      opaque_id: "xyz",
      organization: org,
      service_name: "fake_v1",
      backfill_key: "qwerty",
    )
  end
  let(:admin_role) { Webhookdb::Role.create(name: "admin") }

  before(:each) do
    login_as(customer)
  end

  def max_out_plan_integrations(org)
    # Already have an initial service integration, create one more, then a 3rd which won't be usable
    Webhookdb::Fixtures.service_integration(organization: org).create
    return Webhookdb::Fixtures.service_integration(organization: org).create
  end

  describe "GET v1/organizations/:org_identifier/service_integrations" do
    it "returns all service integrations associated with organization" do
      _ = sint
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
        that_includes(message: include("have any integrations set up yet"))
    end
  end

  describe "POST v1/organizations/:org_identifier/service_integrations/create" do
    let(:internal_role) { Webhookdb::Role.create(name: "internal") }

    it "creates a service integration" do
      membership.update(membership_role: admin_role)
      org.add_feature_role(internal_role)

      post "/v1/organizations/#{org.key}/service_integrations/create", service_name: "fake_v1"

      expect(last_response).to have_status(200)
      new_integration = Webhookdb::ServiceIntegration.where(service_name: "fake_v1", organization: org).first
      expect(new_integration).to_not be_nil
    end

    it "returns a state machine step" do
      membership.update(membership_role: admin_role)
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
      post "/v1/organizations/#{org.key}/service_integrations/create", service_name: "twilio_sms_v1"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "You don't have admin privileges with #{org.name}."),
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
      membership.update(membership_role: admin_role)
      post "/v1/organizations/#{org.key}/service_integrations/create", service_name: "fake_v1"

      available_services = org.available_replicator_names.join("\n\t")
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        needs_input: false,
        output: match("you currently have access to:\n\n\t#{available_services}"),
        complete: true,
      )
    end

    it "returns a state machine step if the given service name is not valid" do
      membership.update(membership_role: admin_role)
      org.add_feature_role(internal_role)

      post "/v1/organizations/#{org.key}/service_integrations/create", service_name: "faake_v1"

      available_services = org.available_replicator_names.join("\n\t")
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        needs_input: false,
        output: match("currently supported by WebhookDB:\n\n\t#{available_services}"),
        complete: true,
      )
    end

    describe "when there is already an integration for the same service" do
      before(:each) do
        _ = sint
      end

      it "422s and asks for confirmation before creating second integration" do
        membership.update(membership_role: admin_role)
        org.add_feature_role(internal_role)

        post "/v1/organizations/#{org.key}/service_integrations/create", service_name: "fake_v1"

        expect(last_response).to have_status(422)
        expect(last_response).to have_json_body.that_includes(
          error: include(code: "prompt_required_params"),
        )
      end

      it "creates second integration if confirmation is recieved" do
        membership.update(membership_role: admin_role)
        org.add_feature_role(internal_role)

        post "/v1/organizations/#{org.key}/service_integrations/create", service_name: "fake_v1", guard_confirm: true

        expect(org.service_integrations(reload: true)).to have_length(2)
      end

      it "does not create second integration if confirmation is not recieved" do
        membership.update(membership_role: admin_role)
        org.add_feature_role(internal_role)

        post "/v1/organizations/#{org.key}/service_integrations/create", service_name: "fake_v1"

        expect(org.service_integrations(reload: true)).to have_length(1)
      end
    end
  end

  describe "POST /v1/service_integrations/:opaque_id" do
    before(:each) do
      # this endpoint should be unauthed, so we will test it unauthed
      logout
      _ = sint
      Sidekiq::Testing.fake! # We don't want to process the jobs
    end

    it "runs the ProcessWebhook job with the data for the webhook", :async do
      header "X-My-Test", "abc"
      expect(Webhookdb::Jobs::ProcessWebhook).to receive(:client_push).with(
        include(
          "args" => match_array(
            [
              include(
                "name" => "webhookdb.serviceintegration.webhook",
                "payload" => match_array(
                  [
                    sint.id,
                    hash_including(
                      "headers" => hash_including("X-My-Test" => "abc"),
                      "body" => {"foo" => 1},
                      "request_path" => "/v1/service_integrations/xyz",
                      "request_method" => "POST",
                    ),
                  ],
                ),
              ),
            ],
          ),
          "queue" => "webhook",
        ),
      )

      post "/v1/service_integrations/xyz", foo: 1

      expect(last_response).to have_status(202)
    end

    it "performs ProcessWebhook synchronously if specified by the service" do
      org.prepare_database_connections
      sint.replicator.create_table
      Webhookdb::Replicator::Fake.process_webhooks_synchronously = {x: 1}.to_json
      header "X-My-Test", "abc"
      post "/v1/service_integrations/xyz", my_id: "myid", at: Time.at(5)

      expect(last_response).to have_status(202)
      expect(sint.replicator.admin_dataset(&:all)).to contain_exactly(include(my_id: "myid"))
      expect(last_response).to have_json_body.that_includes(x: 1)
    ensure
      org.remove_related_database
    end

    it "performs ProcessWebhook synchronously if configured" do
      Webhookdb::Replicator.always_process_synchronously = true
      org.prepare_database_connections
      sint.replicator.create_table
      header "X-My-Test", "abc"
      post "/v1/service_integrations/xyz", my_id: "myid", at: Time.at(5)

      expect(last_response).to have_status(202)
      expect(sint.replicator.admin_dataset(&:all)).to contain_exactly(include(my_id: "myid"))
      expect(last_response).to have_json_body.that_includes(message: "process synchronously")
    ensure
      org.remove_related_database
      Webhookdb::Replicator.reset_configuration
    end

    it "uses netout queue for ProcessWebhook job if integration has deps", :async do
      Webhookdb::Replicator::Fake.upsert_has_deps = true
      expect(Webhookdb::Jobs::ProcessWebhook).to receive(:client_push).
        with(include("queue" => "netout"))

      post "/v1/service_integrations/xyz", foo: 1

      expect(last_response).to have_status(202)
    end

    it "handles default response behavior" do
      expect(Webhookdb::Jobs::ProcessWebhook).to receive(:client_push)

      post "/v1/service_integrations/xyz"

      expect(last_response).to have_status(202)
      expect(last_response.body).to eq('{"o":"k"}')
      expect(last_response.headers).to include("Content-Type" => "application/json")
    end

    it "returns the response from the configured service (not json)" do
      Webhookdb::Replicator::Fake.webhook_response = Webhookdb::WebhookResponse.new(
        status: 203, headers: {"Content-Type" => "text/xml"}, body: "<x></x>",
      )
      expect(Webhookdb::Jobs::ProcessWebhook).to receive(:client_push)

      post "/v1/service_integrations/xyz"

      expect(last_response).to have_status(203)
      expect(last_response.body).to eq("<x></x>")
      expect(last_response.headers).to include("Content-Type" => "text/xml")
    end

    it "returns the response from the configured service (json)" do
      Webhookdb::Replicator::Fake.webhook_response = Webhookdb::WebhookResponse.ok(status: 203)
      expect(Webhookdb::Jobs::ProcessWebhook).to receive(:client_push)

      post "/v1/service_integrations/xyz"

      expect(last_response).to have_status(203)
      expect(last_response.body).to eq('{"o":"k"}')
      expect(last_response.headers).to include("Content-Type" => "application/json")
    end

    it "adds a rejected reason on error (json)" do
      Webhookdb::Replicator::Fake.webhook_response = Webhookdb::WebhookResponse.error("nope", status: 402)

      post "/v1/service_integrations/xyz"

      expect(last_response).to have_status(402)
      expect(last_response.body).to eq('{"message":"nope"}')
      expect(last_response.headers).to include("Whdb-Rejected-Reason" => "nope")
    end

    it "adds a rejected reason on error (not json)" do
      Webhookdb::Replicator::Fake.webhook_response = Webhookdb::WebhookResponse.new(
        status: 402, reason: "erm", body: "<></>", headers: {"Content-Type" => "text/plain"},
      )

      post "/v1/service_integrations/xyz"

      expect(last_response).to have_status(402)
      expect(last_response.body).to eq("<></>")
      expect(last_response.headers).to include("Whdb-Rejected-Reason" => "erm")
    end

    it "400s if there is no active service integration" do
      header "X-My-Test", "abc"
      post "/v1/service_integrations/abc", foo: 1
      expect(last_response).to have_status(400)
    end

    it "runs the job and 200s if in regression mode, even if the webhook is invalid", :regression_mode do
      Webhookdb::Replicator::Fake.webhook_response = Webhookdb::WebhookResponse.new(
        status: 402, reason: "erm", body: "<></>", headers: {"Content-Type" => "text/plain"},
      )
      expect(Webhookdb::Jobs::ProcessWebhook).to receive(:client_push)

      post "/v1/service_integrations/xyz"

      expect(last_response).to have_status(200)
      expect(last_response.body).to eq("<></>")
    end

    it "does not publish if the webhook fails verification", :async do
      Webhookdb::Replicator::Fake.webhook_response = Webhookdb::WebhookResponse.error("no")

      expect do
        post "/v1/service_integrations/xyz"
        expect(last_response).to have_status(401)
      end.to_not publish("webhookdb.serviceintegration.webhook")
    end

    it "captures all HTTP methods and subpaths" do
      header "X-My-Test", "abc"
      expect(Webhookdb::Jobs::ProcessWebhook).to receive(:client_push).with(
        include(
          "args" => match_array(
            [
              include(
                "name" => "webhookdb.serviceintegration.webhook",
                "payload" => match_array(
                  [
                    sint.id,
                    hash_including(
                      "headers" => hash_including("X-My-Test" => "abc"),
                      "body" => {},
                      "request_path" => "/v1/service_integrations/xyz/v2/listings",
                      "request_method" => "DELETE",
                    ),
                  ],
                ),
              ),
            ],
          ),
          "queue" => "webhook",
        ),
      )

      delete "/v1/service_integrations/xyz/v2/listings"

      expect(last_response).to have_status(202)
      expect(Webhookdb::LoggedWebhook.naked.all).to contain_exactly(
        include(
          inserted_at: match_time(Time.now).within(5),
          organization_id: sint.organization_id,
          request_body: "",
          request_headers: hash_including("Host" => "example.org"),
          request_path: "/v1/service_integrations/xyz/v2/listings",
          request_method: "DELETE",
          response_status: 202,
          service_integration_opaque_id: "xyz",
        ),
      )
    end

    it "can exclude headers from logged webhook if defined by the integration" do
      expect(Webhookdb::Jobs::ProcessWebhook).to receive(:client_push)
      Webhookdb::Replicator::Fake.obfuscate_headers_for_logging = ["X-Foo"]
      header "X-Bar", "1"
      header "X-Foo", "2"
      post "/v1/service_integrations/xyz", a: 1
      expect(last_response).to have_status(202)
      expect(Webhookdb::LoggedWebhook.first.request_headers.to_h).to match(
        "Cookie" => "",
        "Host" => "example.org",
        "Trace-Id" => be_a(String),
        "Version" => "HTTP/1.0",
        "X-Bar" => "1",
        "X-Foo" => "***",
      )
    end

    it "can dispatch to a specified service integration" do
      other_sint = Webhookdb::Fixtures.service_integration.create(organization: org)
      Webhookdb::Replicator::Fake.dispatch_request_to_hook = lambda { |req|
        expect(req).to be_a(Rack::Request)
        other_sint.replicator
      }
      expect(Webhookdb::Jobs::ProcessWebhook).to receive(:client_push).with(
        include(
          "args" => match_array(
            [
              include(
                "payload" => match_array(
                  [
                    other_sint.id,
                    hash_including,
                  ],
                ),
              ),
            ],
          ),
        ),
      )

      put "/v1/service_integrations/xyz/sub"

      expect(last_response).to have_status(202)
    end

    it "db logs on success" do
      expect(Webhookdb::Jobs::ProcessWebhook).to receive(:client_push)
      post "/v1/service_integrations/xyz", a: 1
      expect(last_response).to have_status(202)
      expect(Webhookdb::LoggedWebhook.naked.all).to contain_exactly(
        include(
          inserted_at: match_time(Time.now).within(5),
          organization_id: sint.organization_id,
          request_body: '{"a":1}',
          request_headers: hash_including("Host" => "example.org"),
          request_path: "/v1/service_integrations/xyz",
          request_method: "POST",
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
      Webhookdb::Replicator::Fake.webhook_response = Webhookdb::WebhookResponse.error("no")
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
      Webhookdb::Replicator::Fake.webhook_response = RuntimeError.new("foo")
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

    it "does not db log if the retry header is present" do
      expect(Webhookdb::Jobs::ProcessWebhook).to receive(:client_push)
      header Webhookdb::LoggedWebhook::RETRY_HEADER, "1"
      post "/v1/service_integrations/xyz", a: 1
      expect(last_response).to have_status(202)
      expect(Webhookdb::LoggedWebhook.all).to be_empty
    end
  end

  describe "GET /v1/organizations/:org_identifier/service_integrations/:opaque_id/stats" do
    before(:each) do
      # successful webhooks
      Webhookdb::Fixtures.logged_webhook(service_integration_opaque_id: "xyz").success.create
      Webhookdb::Fixtures.logged_webhook(service_integration_opaque_id: "xyz").success.create
      Webhookdb::Fixtures.logged_webhook(service_integration_opaque_id: "xyz").success.create
      # rejected webhooks
      Webhookdb::Fixtures.logged_webhook(service_integration_opaque_id: "xyz").failure.create
      _ = sint
    end

    it "returns expected response" do
      get "/v1/organizations/#{org.key}/service_integrations/xyz/stats"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(count_last_7_days: 4, message: "", display_headers: be_an(Array))
    end
  end

  describe "POST /v1/organizations/:org_identifier/service_integrations/:opaque_id/reset" do
    before(:each) do
      login_as(customer)
      _ = sint
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

  describe "POST /v1/organizations/:org_identifier/service_integrations/:opaque_id/upsert" do
    before(:each) do
      login_as(customer)
    end

    it "upserts a webhook synchronously" do
      org.prepare_database_connections
      svc = sint.replicator
      svc.create_table
      fake_body = {"my_id" => "id", "at" => Time.now}
      post "/v1/organizations/#{org.key}/service_integrations/#{sint.opaque_id}/upsert", fake_body

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(message: /You have upserted/)

      svc.readonly_dataset do |ds|
        expect(ds.all).to contain_exactly(include(my_id: "id"))
      end
    end

    it "returns a friendly 400 error if error occurs on upsert" do
      org.prepare_database_connections
      svc = sint.replicator
      svc.create_table
      post "/v1/organizations/#{org.key}/service_integrations/#{sint.opaque_id}/upsert", {}

      expect(last_response).to have_status(400)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: include("something has gone wrong")),
      )
    end

    it "returns a 401 error if request is unauthed" do
      logout
      post "/v1/organizations/#{org.key}/service_integrations/xyz/upsert", {}

      expect(last_response).to have_status(401)
    end
  end

  describe "POST /v1/organizations/:org_identifier/service_integrations/:opaque_id/backfill" do
    before(:each) do
      login_as(customer)
      _ = sint
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
      end.to publish("webhookdb.serviceintegration.backfill").with_payload([sint.id, {"cascade" => true}])
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(output: /backfill of fake_v1 \(xyz\)\. Data/)
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
      _ = sint
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
      _ = sint
    end

    it "calls the state machine with the given field and value and returns the result" do
      post "/v1/organizations/#{org.key}/service_integrations/xyz/transition/webhook_secret", value: "open sesame"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        needs_input: false,
        prompt: "",
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

  describe "POST /v1/organizations/:key/service_integrations/:opaque_id/delete" do
    before(:each) do
      login_as(customer)
      membership.update(membership_role: admin_role)
      _ = sint
    end

    it "destroys the integration and drops the table" do
      org.prepare_database_connections
      sint.replicator.create_table

      post "/v1/organizations/#{org.key}/service_integrations/xyz/delete", confirm: sint.table_name

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(message: /deleted all secrets for.*containing its data has been dropped./)

      expect(org.service_integrations_dataset.all).to be_empty

      expect do
        sint.replicator.admin_dataset(&:count)
      end.to raise_error(Sequel::DatabaseError, /PG::UndefinedTable/)
    ensure
      org.remove_related_database
    end

    it "succeeds even if the table does not exist (in case it was never created)" do
      org.prepare_database_connections

      post "/v1/organizations/#{org.key}/service_integrations/xyz/delete", confirm: " #{sint.table_name} \n"

      expect(last_response).to have_status(200)
      expect(org.service_integrations_dataset.all).to be_empty
    ensure
      org.remove_related_database
    end

    it "422s if the table name is not given as the confirmation value" do
      post "/v1/organizations/#{org.key}/service_integrations/xyz/delete"

      expect(last_response).to have_status(422)
      expect(last_response).to have_json_body.that_includes(
        error: include(code: "prompt_required_params"),
      )

      post "/v1/organizations/#{org.key}/service_integrations/xyz/delete", confirm: sint.table_name + "x"

      expect(last_response).to have_status(422)
      expect(last_response).to have_json_body.that_includes(
        error: include(code: "prompt_required_params"),
      )
    end

    it "403s if the current user cannot modify the integration due to org permissions" do
      membership.update(membership_role: Webhookdb::Role.non_admin_role)

      post "/v1/organizations/#{org.key}/service_integrations/xyz/delete", confirm: sint.table_name

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: /admin privileges/),
      )
    end
  end

  describe "POST /v1/organizations/:key/service_integrations/:opaque_id/rename_table" do
    before(:each) do
      org.prepare_database_connections
      sint.replicator.create_table
    end

    after(:each) do
      org.remove_related_database
    end

    it "renames the given table" do
      customer.all_memberships_dataset.first.update(membership_role: admin_role)

      post "/v1/organizations/#{org.key}/service_integrations/xyz/rename_table", new_name: "table5"

      expect(last_response).to have_status(200)
      expect(org.readonly_connection(&:tables)).to include(:table5)
      expect(sint.refresh).to have_attributes(table_name: "table5")
    end

    it "errors if the user is not an admin" do
      post "/v1/organizations/#{org.key}/service_integrations/xyz/rename_table", new_name: "table5"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: /You don't have admin/),
      )
    end

    it "propagates underlying error messages" do
      customer.all_memberships_dataset.first.update(membership_role: admin_role)

      post "/v1/organizations/#{org.key}/service_integrations/xyz/rename_table", new_name: "do thing"

      expect(last_response).to have_status(400)
      expect(last_response).to have_json_body.that_includes(error: include(message: /with double quotes around/))
    end
  end
end
