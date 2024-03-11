# frozen_string_literal: true

require "webhookdb/api/install"

RSpec.describe Webhookdb::API::Install, :db, reset_configuration: Webhookdb::Customer do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }
  let!(:org) { Webhookdb::Fixtures.organization.create }

  def add_front_auth_headers(body, secret=Webhookdb::Front.app_secret)
    tsval = Time.new(2023, 4, 7).to_i.to_s
    base_string = "#{tsval}:#{body.to_json}"
    signature = OpenSSL::HMAC.base64digest(OpenSSL::Digest.new("sha256"), secret, base_string)
    header "X-Front-Request-Timestamp", tsval
    header "X-Front-Signature", signature
    return body
  end

  describe "GET /v1/install/:provider" do
    it "200s" do
      get "/v1/install/fake"

      expect(last_response).to have_status(200)
    end

    it "403s for an invalid provider" do
      get "/v1/install/invalid"

      expect(last_response).to have_status(403)
    end
  end

  describe "POST /v1/install/:provider" do
    it "creates an oauth session and redirects" do
      post "/v1/install/fake"

      expect(last_response).to have_status(302)
      expect(Webhookdb::Oauth::Session.all).to have_length(1)
      expect(last_response.headers).to include(
        "Location" => match(%r{http://localhost:18001/v1/install/fake_oauth_authorization\?client_id=fakeclient&state=[a-z0-9]+}),
      )
    end
  end

  describe "GET /v1/install/:provider/callback" do
    let(:session) { Webhookdb::Fixtures.oauth_session.create }
    let(:state) { session.oauth_state }
    let(:code) { SecureRandom.hex(4) }

    it "403s if there is no valid session with the given id" do
      session.update(used_at: Time.now)

      get("/v1/install/fake/callback", state:, code:)

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(error: include(code: "forbidden"))
    end

    describe "when the OAuth provider requires WebhookDB login" do
      before(:each) do
        Webhookdb::Oauth::FakeProvider.requires_webhookdb_auth = true
      end

      it "302s to the login page" do
        get("/v1/install/fake/callback", code:, state:)
        expect(last_response).to have_status(302)
        expect(last_response.headers).to include("Location" => "/v1/install/fake/login?state=#{state}")
      end

      it "updates oauth session with authorization code" do
        get("/v1/install/fake/callback", code:, state:)
        expect(session.refresh).to have_attributes(authorization_code: code, used_at: nil)
      end
    end

    describe "when the OAuth provider can create a user using the token" do
      before(:each) do
        Webhookdb::Oauth::FakeProvider.requires_webhookdb_auth = false
      end

      it "renders success page and updates the session" do
        get("/v1/install/fake/callback", state:, code:)
        expect(last_response).to have_status(200)
        expect(last_response.body).to include(
          "We are now listening for updates to resources in your Fake account.",
        )
        expect(session.refresh).to have_attributes(
          authorization_code: code, customer: be_present, used_at: match_time(:now),
        )
      end

      it "creates a customer if needed" do
        get("/v1/install/fake/callback", state:, code:)

        expect(last_response).to have_status(200)
        expect(Webhookdb::Customer.all).to contain_exactly(have_attributes(email: "access-#{code}@webhookdb.com"))
      end

      it "uses an existing customer if one matches the email" do
        customer = Webhookdb::Fixtures.customer.create(email: "access-#{code}@webhookdb.com")

        get("/v1/install/fake/callback", state:, code:)

        expect(last_response).to have_status(200)
        expect(Webhookdb::Customer.all).to contain_exactly(be === customer)
      end

      it "creates integrations on default organization" do
        customer = Webhookdb::Fixtures.customer.create(email: "access-#{code}@webhookdb.com")
        Webhookdb::Fixtures.organization_membership.org(org).customer(customer).admin.verified.default.create

        get("/v1/install/fake/callback", state:, code:)

        expect(last_response).to have_status(200)
        expect(org.refresh.service_integrations).to contain_exactly(have_attributes(service_name: "fake_v1"))
      end
    end
  end

  describe "POST /v1/install/:provider/login" do
    let(:customer) { Webhookdb::Fixtures.customer.create }
    let(:session) { Webhookdb::Fixtures.oauth_session.create(authorization_code: "front_test_auth", customer:) }
    let(:state) { session.oauth_state }
    let(:email) { customer.email }

    describe "OTP token param is not present" do
      it "renders login form for existing customer" do
        post("/v1/install/fake/login", state:, email:)

        expect(last_response).to have_status(200)
        expect(last_response.body).to include(
          "Hello again! To finish logging in, please look for an email",
        )
      end

      it "creates new customer and renders login form" do
        post("/v1/install/fake/login", state:, email: "new@customer.com")

        expect(last_response).to have_status(200)
        expect(last_response.body).to include(
          "To finish registering, please look for an email we just",
        )
        new_customer = Webhookdb::Customer[email: "new@customer.com"]
        expect(new_customer).to not_be_nil
      end

      it "expires existing reset codes for an existing customer and adds a new one" do
        code = Webhookdb::Fixtures.reset_code(customer:).create

        post("/v1/install/fake/login", state:, email:)

        expect(last_response).to have_status(200)
        expect(code.refresh).to be_expired
        new_code = customer.refresh.reset_codes.first
        expect(new_code).to_not be_expired
        expect(new_code).to have_attributes(transport: "email")
      end

      it "updates the session with customer" do
        post("/v1/install/fake/login", state:, email:)

        expect(last_response).to have_status(200)
        oauth_session = Webhookdb::Oauth::Session.where(oauth_state: state, customer:).first
        expect(oauth_session).to_not be_nil
      end
    end

    describe "OTP token param is present" do
      let(:reset_code) { Webhookdb::Fixtures.reset_code(customer:).create }
      let(:otp_token) { reset_code.token }

      before(:each) do
        org.prepare_database_connections
      end

      after(:each) do
        org.remove_related_database
      end

      it "skips auth if customer auth should be skipped", reset_configuration: Webhookdb::Customer do
        Webhookdb::Customer.skip_authentication = true

        Webhookdb::Fixtures.organization_membership.org(org).customer(customer).admin.verified.default.create

        post("/v1/install/fake/login", state:, email:, otp_token: "invalid token")

        expect(last_response).to have_status(200)
        expect(last_response.body).to include(
          "We are now listening for updates to resources in your Fake account.",
        )
        expect(last_response.body).to include(org.readonly_connection_url)
      end

      it "renders success message on success" do
        Webhookdb::Fixtures.organization_membership.org(org).customer(customer).admin.verified.default.create

        post("/v1/install/fake/login", state:, email:, otp_token:)

        expect(last_response).to have_status(200)
        expect(last_response.body).to include(
          "We are now listening for updates to resources in your Fake account.",
        )
        expect(last_response.body).to include(org.readonly_connection_url)
      end

      it "403s if there is no session with the given id" do
        session.destroy
        post("/v1/install/fake/login", state:, email:, otp_token:)

        expect(last_response).to have_status(403)
        expect(last_response).to have_json_body.that_includes(error: include(code: "forbidden"))
      end

      it "403s if the otp token is invalid" do
        post "/v1/install/fake/login", state:, email:, otp_token: reset_code.token + "1"

        expect(last_response).to have_status(403)
        expect(last_response.body).to include(
          "Sorry, that token is invalid. Please try again.",
        )
      end

      it "creates integrations on default organization when specified for customer" do
        Webhookdb::Fixtures.organization_membership.org(org).customer(customer).admin.verified.default.create

        post("/v1/install/fake/login", state:, email:, otp_token:)
        expect(last_response).to have_status(200)
        expect(org.refresh.service_integrations).to contain_exactly(
          have_attributes(service_name: "fake_v1"),
        )
      end

      it "creates integrations on verified organization when no default specified for customer" do
        Webhookdb::Fixtures.organization_membership.org(org).customer(customer).admin.verified.create

        post("/v1/install/fake/login", state:, email:, otp_token:)

        expect(last_response).to have_status(200)
        expect(org.refresh.service_integrations).to contain_exactly(
          have_attributes(service_name: "fake_v1"),
        )
      end

      it "creates integrations on new organization when customer has no verified memberships" do
        post("/v1/install/fake/login", state:, email:, otp_token:)

        expect(last_response).to have_status(200)
        new_org = Webhookdb::Organization[name: "#{customer.email} Org"]
        expect(new_org).to_not be_nil
        expect(new_org.refresh.service_integrations).to contain_exactly(
          have_attributes(service_name: "fake_v1"),
        )
      end

      it "403s when customer is not an admin for any organizations" do
        Webhookdb::Fixtures.organization_membership.org(org).customer(customer).verified.create

        post("/v1/install/fake/login", state:, email:, otp_token:)

        expect(last_response).to have_status(403)
        expect(last_response.body).to include(
          "You must be an administrator of your WebhookDB organization",
        )
      end
    end
  end

  describe "POST /v1/install/front/webhook" do
    let(:root_sint) do
      Webhookdb::Fixtures.service_integration.create(
        organization: org,
        service_name: "front_marketplace_root_v1",
        api_url: "webhookdb_test.api.frontapp.com",
      )
    end
    let!(:message_sint) do
      Webhookdb::Fixtures.service_integration.depending_on(root_sint).create(
        organization: org,
        service_name: "front_message_v1",
      )
    end

    let(:body) { load_fixture_data("front/message_webhook") }

    describe "initial request verification" do
      before(:each) do
        header "X-Front-Challenge", "initial_request"
      end

      it "401s if webhook auth header is missing" do
        post "/v1/install/front/webhook", body
        expect(last_response).to have_status(401)

        expect(Webhookdb::LoggedWebhook.all).to be_empty
      end

      it "401s if webhook auth header is invalid" do
        add_front_auth_headers(body)
        header "X-Front-Signature", "front_invalid_auth"

        post "/v1/install/front/webhook", body

        expect(last_response).to have_status(401)
        expect(Webhookdb::LoggedWebhook.all).to be_empty
      end

      it "200s and returns X-Front-Challenge string" do
        add_front_auth_headers(body)
        header "X-Front-Challenge", "initial_request"

        post "/v1/install/front/webhook", body

        expect(last_response).to have_status(200)
        expect(last_response).to have_json_body.that_includes(
          challenge: "initial_request",
        )
        expect(Webhookdb::LoggedWebhook.all).to be_empty
      end
    end

    it "noops if there is no integration with given app id" do
      message_sint.destroy
      root_sint.destroy

      post "/v1/install/front/webhook", body

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(message: "unregistered app")
      expect(Webhookdb::LoggedWebhook.all).to contain_exactly(
        include(service_integration_opaque_id: start_with("front_marketplace_host-https://web")),
      )
    end

    it "noops if there is no integration with given topic id" do
      message_sint.destroy

      post "/v1/install/front/webhook", body

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(message: "invalid topic")
      expect(Webhookdb::LoggedWebhook.all).to contain_exactly(
        include(service_integration_opaque_id: start_with("front_marketplace_host-https://web")),
      )
    end

    it "401s if webhook auth header is missing" do
      post "/v1/install/front/webhook", body

      expect(last_response).to have_status(401)
      expect(Webhookdb::LoggedWebhook.all).to contain_exactly(
        include(service_integration_opaque_id: start_with("svi_")),
      )
    end

    it "401s if webhook auth header is invalid" do
      add_front_auth_headers(body)
      header "X-Front-Signature", "front_invalid_auth"

      post "/v1/install/front/webhook", body

      expect(last_response).to have_status(401)
      expect(Webhookdb::LoggedWebhook.all).to contain_exactly(
        include(service_integration_opaque_id: start_with("svi_")),
      )
    end

    it "runs the ProcessWebhook job with the data for the webhook", :async do
      add_front_auth_headers(body)

      expect(Webhookdb::Jobs::ProcessWebhook).to receive(:client_push).with(
        include(
          "args" => contain_exactly(include("name" => "webhookdb.serviceintegration.webhook")),
          "queue" => "webhook",
        ),
      )

      post "/v1/install/front/webhook", body
      expect(last_response).to have_status(200)
      expect(Webhookdb::LoggedWebhook.all).to contain_exactly(
        include(service_integration_opaque_id: start_with("svi_")),
      )
    end
  end

  describe "POST /v1/install/front_signalwire/channel" do
    let(:org) { Webhookdb::Fixtures.organization.create }
    let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }
    let(:signalwire_sint) { fac.create(service_name: "signalwire_message_v1") }
    let(:frontapp_sint) { fac.create(service_name: "front_marketplace_root_v1") }
    let(:sint) do
      fac.
        depending_on(signalwire_sint).
        with_api_key.
        create(service_name: "front_signalwire_message_channel_app_v1")
    end

    def add_swfront_auth_headers(body)
      return add_front_auth_headers(body, Webhookdb::Front.signalwire_channel_app_secret)
    end

    it "401s if the api key is missing" do
      body = add_swfront_auth_headers({type: "authorization"})
      post "/v1/install/front_signalwire/channel", body

      expect(last_response).to have_status(401)
    end

    it "401s if the api key is invalid" do
      body = add_swfront_auth_headers({type: "authorization"})
      header "Authorization", "Bearer 123"

      post "/v1/install/front_signalwire/channel", body

      expect(last_response).to have_status(401)
    end

    describe "with the WebhookDB API key" do
      before(:each) do
        header "Authorization", "Bearer #{sint.webhookdb_api_key}"
      end

      it "401s if webhook auth header is missing/invalid" do
        body = add_swfront_auth_headers({type: "authorization"})
        header "X-Front-Signature", "invalid"

        post "/v1/install/front_signalwire/channel", body

        expect(last_response).to have_status(401)

        expect(Webhookdb::LoggedWebhook.all).to contain_exactly(
          include(service_integration_opaque_id: start_with("svi_")),
        )
      end

      it "400s if the type is invalid" do
        body = add_swfront_auth_headers({type: "invalid"})
        post "/v1/install/front_signalwire/channel", body

        expect(last_response).to have_status(400)
      end

      describe "with an authorization type" do
        it "responds with success" do
          body = add_swfront_auth_headers(type: "authorization", payload: {channel_id: "123"})
          post "/v1/install/front_signalwire/channel", body

          expect(last_response).to have_status(200)
          expect(last_response).to have_json_body.that_includes(
            type: "success",
            webhook_url: "http://localhost:18001/v1/install/front_signalwire/channel",
          )
          expect(sint.refresh).to have_attributes(backfill_key: "123")
        end
      end

      describe "with a delete type" do
        it "deletes the integration (using DELETE http method)" do
          body = add_swfront_auth_headers({type: "delete"})
          delete "/v1/install/front_signalwire/channel", body

          expect(last_response).to have_status(200)
          expect(Webhookdb::ServiceIntegration[sint.id]).to be_nil
        end
      end

      describe "with a message type" do
        before(:each) do
          sint.organization.prepare_database_connections
          sint.replicator.create_table
        end

        after(:each) do
          sint.organization.remove_related_database
        end

        it "responds with the message details" do
          payload = {
            _links: {
              self: "https://api2.frontapp.com/messages/msg_55c8c149",
              related: {
                conversation: "https://api2.frontapp.com/conversations/cnv_55c8c149",
                message_replied_to: "https://api2.frontapp.com/messages/msg_1ab23cd4",
              },
            },
            id: "msg_55c8c149",
            type: "email",
            is_inbound: true,
            created_at: 1_453_770_984.123,
            blurb: "Anything less than immortality is a...",
            author: {},
            recipients: [{handle: "3334445555", role: "to"}],
            body: "Anything less than immortality is a complete waste of time.",
            text: "Anything less than immortality is a complete waste of time.",
            attachments: [],
            metadata: {},
          }
          body = add_swfront_auth_headers({type: "message", payload:})
          post "/v1/install/front_signalwire/channel", body

          expect(last_response).to have_status(200)
          expect(last_response).to have_json_body.that_includes(
            type: "success",
            external_id: "msg_55c8c149",
            external_conversation_id: "+13334445555",
          )
        end
      end
    end
  end

  describe "POST /v1/install/intercom/webhook" do
    let(:root_sint) do
      Webhookdb::Fixtures.service_integration.create(
        organization: org,
        service_name: "intercom_marketplace_root_v1",
        api_url: "lithic_tech_intercom_abc",
      )
    end
    let!(:contact_sint) do
      Webhookdb::Fixtures.service_integration.depending_on(root_sint).create(
        organization: org,
        service_name: "intercom_contact_v1",
      )
    end

    let(:body) { load_fixture_data("intercom/contact_webhook") }

    def valid_auth_header
      return "sha1=#{OpenSSL::HMAC.hexdigest('SHA1', Webhookdb::Intercom.client_secret, body.to_json)}"
    end

    it "401s if webhook auth header is missing" do
      post "/v1/install/intercom/webhook", body
      expect(last_response).to have_status(401)
      expect(Webhookdb::LoggedWebhook.all).to contain_exactly(
        include(service_integration_opaque_id: start_with("svi_")),
      )
    end

    it "401s if webhook auth header is invalid" do
      header "X-Hub-Signature", "intercom_invalid_auth"

      post "/v1/install/intercom/webhook", body
      expect(last_response).to have_status(401)
      expect(Webhookdb::LoggedWebhook.all).to contain_exactly(
        include(service_integration_opaque_id: start_with("svi_")),
      )
    end

    it "noops if there is no integration with given app id" do
      header "X-Hub-Signature", valid_auth_header

      contact_sint.destroy
      root_sint.destroy

      post "/v1/install/intercom/webhook", body

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(message: "unregistered app")
      expect(Webhookdb::LoggedWebhook.all).to contain_exactly(
        include(service_integration_opaque_id: start_with("intercom_marketplace_appid-lithic")),
      )
    end

    it "noops if there is no integration with given topic id" do
      header "X-Hub-Signature", valid_auth_header

      contact_sint.destroy

      post "/v1/install/intercom/webhook", body

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(message: "invalid topic")
      expect(Webhookdb::LoggedWebhook.all).to contain_exactly(
        include(service_integration_opaque_id: start_with("intercom_marketplace_appid-lithic")),
      )
    end

    it "runs the ProcessWebhook job with the data for the webhook", :async do
      header "X-Hub-Signature", valid_auth_header
      expect(Webhookdb::Jobs::ProcessWebhook).to receive(:client_push).with(
        include(
          "args" => contain_exactly(include("name" => "webhookdb.serviceintegration.webhook")),
          "queue" => "webhook",
        ),
      )

      post "/v1/install/intercom/webhook", body

      expect(last_response).to have_status(202)
      expect(Webhookdb::LoggedWebhook.all).to contain_exactly(
        include(service_integration_opaque_id: start_with("")),
      )
    end
  end

  describe "POST /v1/install/intercom/uninstall" do
    it "deletes integrations associated with given app id" do
      body = {app_id: "ghi567"}

      org.prepare_database_connections
      root = Webhookdb::Fixtures.service_integration.create(
        service_name: "intercom_marketplace_root_v1",
        api_url: "ghi567",
        organization: org,
      )
      Webhookdb::Fixtures.service_integration.depending_on(root).create(service_name: "intercom_contact_v1",
                                                                        organization: org,)
      Webhookdb::Fixtures.service_integration.depending_on(root).create(service_name: "intercom_conversation_v1",
                                                                        organization: org,)

      post "/v1/install/intercom/uninstall", body
      expect(last_response).to have_status(200)
      expect(Webhookdb::ServiceIntegration.where(organization: org).all).to be_empty
    end
  end

  describe "POST /v1/install/intercom/health" do
    it "returns 'OK' status" do
      body = {workspace_id: "apple_banana"}
      post "/v1/install/intercom/health", body
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(state: "OK")
    end
  end
end
