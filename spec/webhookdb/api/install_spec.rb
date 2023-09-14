# frozen_string_literal: true

require "webhookdb/api/install"

RSpec.describe Webhookdb::API::Install, :db do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }
  let!(:org) { Webhookdb::Fixtures.organization.create }
  let!(:customer) { Webhookdb::Fixtures.customer.create(email: "ginger@example.com") }

  describe "GET /v1/install/front" do
    it "200s" do
      get "/v1/install/front"
      expect(last_response).to have_status(200)
    end
  end

  describe "POST /v1/install/front" do
    it "creates an oauth session" do
      post "/v1/install/front"
      expect(Webhookdb::Oauth::Session.first).to_not be_nil
    end

    it "302s to the provider auth url" do
      post "/v1/install/front"
      expect(last_response).to have_status(302)
      expect(last_response.headers).to include(
        "Location" => start_with("https://app.frontapp.com/oauth/authorize?response_type"),
      )
    end
  end

  describe "GET /v1/install/<provider>/callback" do
    let(:session) { Webhookdb::Fixtures.oauth_session.create }
    let(:state) { session.oauth_state }
    let(:code) { SecureRandom.hex(4) }

    it "403s if there is no valid session with the given id" do
      session.update(used_at: Time.now)

      get("/v1/install/intercom/callback", state:, code:)

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(error: include(code: "forbidden"))
    end

    describe "when the OAuth provider requires WebhookDB login" do
      it "302s to the login page" do
        get("/v1/install/front/callback", code:, state:)
        expect(last_response).to have_status(302)
        expect(last_response.headers).to include("Location" => "/v1/install/front/login?state=#{state}")
      end

      it "updates oauth session with authorization code" do
        get("/v1/install/front/callback", code:, state:)
        expect(session.refresh).to have_attributes(authorization_code: code, used_at: nil)
      end
    end

    describe "when the OAuth provider can create a user using the token" do
      def stub_token_request
        return stub_request(:post, "https://api.intercom.io/auth/eagle/token").
            to_return(json_response(load_fixture_data("intercom/token_response")))
      end

      def stub_intercom_user_request
        return stub_request(:get, "https://api.intercom.io/me").
            to_return(json_response(load_fixture_data("intercom/get_user")))
      end

      it "renders success page and updates the session" do
        requests = [stub_token_request, stub_intercom_user_request]

        get("/v1/install/intercom/callback", state:, code:)
        expect(last_response).to have_status(200)
        expect(last_response.body).to include(
          "We are now checking for updates to resources in your Intercom account.",
        )
        expect(requests).to all(have_been_made)
        expect(session.refresh).to have_attributes(
          authorization_code: code, customer: be_present, used_at: match_time(:now),
        )
      end

      it "creates a customer if needed" do
        customer.destroy
        requests = [stub_token_request, stub_intercom_user_request]

        get("/v1/install/intercom/callback", state:, code:)
        expect(last_response).to have_status(200)

        expect(requests).to all(have_been_made)
        expect(Webhookdb::Customer.all).to contain_exactly(have_attributes(email: "ginger@example.com"))
      end

      it "uses an existing customer if one matches the email" do
        requests = [stub_token_request, stub_intercom_user_request]

        get("/v1/install/intercom/callback", state:, code:)
        expect(last_response).to have_status(200)

        expect(requests).to all(have_been_made)
        expect(Webhookdb::Customer.all).to contain_exactly(have_attributes(email: "ginger@example.com"))
      end

      it "creates integrations on default organization" do
        Webhookdb::Fixtures.organization_membership.org(org).customer(customer).admin.verified.default.create
        requests = [stub_token_request, stub_intercom_user_request]

        get("/v1/install/intercom/callback", state:, code:)
        expect(last_response).to have_status(200)
        expect(requests).to all(have_been_made)

        expect(org.refresh.service_integrations).to contain_exactly(
          # We can't match on an encrypted field, but the backfill_key of the root should be the
          # Intercom auth token. We can just test that the field isn't nil
          have_attributes(
            service_name: "intercom_marketplace_root_v1",
            # backfill_key: not_be_nil,
            api_url: "lithic_tech_intercom_abc",
          ),
          have_attributes(service_name: "intercom_conversation_v1"),
          have_attributes(service_name: "intercom_contact_v1"),
        )

        expect(Webhookdb::BackfillJob.all).to contain_exactly(
          have_attributes(
            service_integration: have_attributes(service_name: "intercom_contact_v1"),
            incremental: true,
          ),
          have_attributes(
            service_integration: have_attributes(service_name: "intercom_conversation_v1"),
            incremental: true,
          ),
        )
      end
    end
  end

  describe "POST /v1/install/front/login" do
    let(:customer) { Webhookdb::Fixtures.customer.create }
    let(:session) { Webhookdb::Fixtures.oauth_session.create(authorization_code: "front_test_auth", customer:) }
    let(:state) { session.oauth_state }
    let(:email) { customer.email }

    describe "OTP token param is not present" do
      it "renders login form for existing customer" do
        post("/v1/install/front/login", state:, email:)

        expect(last_response).to have_status(200)
        expect(last_response.body).to include(
          "Hello again! To finish logging in, please look for an email",
        )
      end

      it "creates new customer and renders login form" do
        post("/v1/install/front/login", state:, email: "new@customer.com")

        expect(last_response).to have_status(200)
        expect(last_response.body).to include(
          "To finish registering, please look for an email we just",
        )
        new_customer = Webhookdb::Customer[email: "new@customer.com"]
        expect(new_customer).to not_be_nil
      end

      it "expires existing reset codes for an existing customer and adds a new one" do
        code = Webhookdb::Fixtures.reset_code(customer:).create

        post("/v1/install/front/login", state:, email:)

        expect(last_response).to have_status(200)
        expect(code.refresh).to be_expired
        new_code = customer.refresh.reset_codes.first
        expect(new_code).to_not be_expired
        expect(new_code).to have_attributes(transport: "email")
      end

      it "updates the session with customer" do
        post("/v1/install/front/login", state:, email:)

        expect(last_response).to have_status(200)
        oauth_session = Webhookdb::Oauth::Session.where(oauth_state: state, customer:).first
        expect(oauth_session).to_not be_nil
      end
    end

    describe "OTP token param is present" do
      let(:front_instance_api_url) { "webhookdb_test.api.frontapp.com" }
      let(:reset_code) { Webhookdb::Fixtures.reset_code(customer:).create }
      let(:otp_token) { reset_code.token }

      before(:each) do
        org.prepare_database_connections
      end

      after(:each) do
        org.remove_related_database
      end

      def stub_auth_token_request
        body = {
          "code" => "front_test_auth",
          "redirect_uri" => Webhookdb::Front.oauth_callback_url,
          "grant_type" => "authorization_code",
        }.to_json
        return stub_request(:post, "https://app.frontapp.com/oauth/token").with(body:).
            to_return(json_response(load_fixture_data("front/auth_token_response")))
      end

      def stub_token_info_request
        return stub_request(:get, "https://api2.frontapp.com/me").
            to_return(json_response(load_fixture_data("front/token_info_response")))
      end

      it "renders success message on success" do
        Webhookdb::Fixtures.organization_membership.org(org).customer(customer).admin.verified.default.create
        requests = [stub_auth_token_request, stub_token_info_request]

        post("/v1/install/front/login", state:, email:, otp_token:)

        expect(last_response).to have_status(200)
        expect(last_response.body).to include(
          "We are now listening for updates to resources in your Front account.",
        )
        expect(last_response.body).to include(org.readonly_connection_url)
        expect(requests).to all(have_been_made)
      end

      it "403s if there is no session with the given id" do
        session.destroy
        post("/v1/install/front/login", state:, email:, otp_token:)

        expect(last_response).to have_status(403)
        expect(last_response).to have_json_body.that_includes(error: include(code: "forbidden"))
      end

      it "403s if the otp token is invalid" do
        post "/v1/install/front/login", state:, email:, otp_token: reset_code.token + "1"

        expect(last_response).to have_status(403)
        expect(last_response.body).to include(
          "Sorry, that token is invalid. Please try again.",
        )
      end

      it "creates integrations on default organization when specified for customer" do
        Webhookdb::Fixtures.organization_membership.org(org).customer(customer).admin.verified.default.create
        requests = [stub_auth_token_request, stub_token_info_request]

        post("/v1/install/front/login", state:, email:, otp_token:)
        expect(last_response).to have_status(200)
        expect(requests).to all(have_been_made)

        expect(org.refresh.service_integrations).to contain_exactly(
          # We can't match on an encrypted field, but the backfill_key of the root should be the
          # Front refresh token. We can just test that the field isn't nil
          have_attributes(
            service_name: "front_marketplace_root_v1",
            backfill_key: not_be_nil,
            api_url: front_instance_api_url,
          ),
          have_attributes(service_name: "front_message_v1"),
          have_attributes(service_name: "front_conversation_v1"),
        )
      end

      it "creates integrations on verified organization when no default specified for customer" do
        Webhookdb::Fixtures.organization_membership.org(org).customer(customer).admin.verified.create
        requests = [stub_auth_token_request, stub_token_info_request]

        post("/v1/install/front/login", state:, email:, otp_token:)
        expect(last_response).to have_status(200)
        expect(requests).to all(have_been_made)

        expect(org.refresh.service_integrations).to contain_exactly(
          have_attributes(service_name: "front_marketplace_root_v1"),
          have_attributes(service_name: "front_message_v1"),
          have_attributes(service_name: "front_conversation_v1"),
        )
      end

      it "creates integrations on new organization when customer has no verified memberships" do
        requests = [stub_auth_token_request, stub_token_info_request]

        post("/v1/install/front/login", state:, email:, otp_token:)
        expect(last_response).to have_status(200)
        expect(requests).to all(have_been_made)

        new_org = Webhookdb::Organization[name: "#{customer.email} Org"]
        expect(new_org).to_not be_nil
        expect(new_org.refresh.service_integrations).to contain_exactly(
          have_attributes(service_name: "front_marketplace_root_v1"),
          have_attributes(service_name: "front_message_v1"),
          have_attributes(service_name: "front_conversation_v1"),
        )
      end

      it "403s when customer is not an admin for any organizations" do
        Webhookdb::Fixtures.organization_membership.org(org).customer(customer).verified.create

        post("/v1/install/front/login", state:, email:, otp_token:)

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
    let(:front_timestamp_header) { Time.new(2023, 4, 7).to_i.to_s }

    def valid_auth_header
      base_string = "#{front_timestamp_header}:#{body.to_json}"
      return OpenSSL::HMAC.base64digest(OpenSSL::Digest.new("sha256"), Webhookdb::Front.api_secret, base_string)
    end

    describe "initial request verification" do
      it "401s if webhook auth header is missing" do
        header "X_Front_Request_Timestamp", front_timestamp_header
        header "X-Front-Challenge", "initial_request"

        post "/v1/install/front/webhook", body
        expect(last_response).to have_status(401)
      end

      it "401s if webhook auth header is invalid" do
        header "X_Front_Request_Timestamp", front_timestamp_header
        header "X_Front_Signature", "front_invalid_auth"
        header "X-Front-Challenge", "initial_request"

        post "/v1/install/front/webhook", body
        expect(last_response).to have_status(401)
      end

      it "200s and returns X-Front-Challenge string" do
        header "X_Front_Request_Timestamp", front_timestamp_header
        header "X_Front_Signature", valid_auth_header
        header "X-Front-Challenge", "initial_request"

        post "/v1/install/front/webhook", body
        expect(last_response).to have_status(200)
        expect(last_response).to have_json_body.that_includes(
          challenge: "initial_request",
        )
      end
    end

    it "noops if there is no integration with given app id" do
      message_sint.destroy
      root_sint.destroy

      post "/v1/install/front/webhook", body

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(message: "unregistered app")
    end

    it "noops if there is no integration with given topic id" do
      message_sint.destroy

      post "/v1/install/front/webhook", body

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(message: "invalid topic")
    end

    it "401s if webhook auth header is missing" do
      post "/v1/install/front/webhook", body
      expect(last_response).to have_status(401)
    end

    it "401s if webhook auth header is invalid" do
      header "X_Front_Request_Timestamp", front_timestamp_header
      header "X_Front_Signature", "front_invalid_auth"

      post "/v1/install/front/webhook", body
      expect(last_response).to have_status(401)
    end

    it "runs the ProcessWebhook job with the data for the webhook", :async do
      header "X_Front_Request_Timestamp", front_timestamp_header
      header "X_Front_Signature", valid_auth_header

      expect(Webhookdb::Jobs::ProcessWebhook).to receive(:client_push).with(
        include(
          "args" => contain_exactly(include("name" => "webhookdb.serviceintegration.webhook")),
          "queue" => "webhook",
        ),
      )

      post "/v1/install/front/webhook", body
      expect(last_response).to have_status(200)
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
    end

    it "401s if webhook auth header is invalid" do
      header "X_Hub_Signature", "intercom_invalid_auth"

      post "/v1/install/intercom/webhook", body
      expect(last_response).to have_status(401)
    end

    it "noops if there is no integration with given app id" do
      header "X_Hub_Signature", valid_auth_header

      contact_sint.destroy
      root_sint.destroy

      post "/v1/install/intercom/webhook", body

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(message: "unregistered app")
    end

    it "noops if there is no integration with given topic id" do
      header "X_Hub_Signature", valid_auth_header

      contact_sint.destroy

      post "/v1/install/intercom/webhook", body

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(message: "invalid topic")
    end

    it "runs the ProcessWebhook job with the data for the webhook", :async do
      header "X_Hub_Signature", valid_auth_header
      expect(Webhookdb::Jobs::ProcessWebhook).to receive(:client_push).with(
        include(
          "args" => contain_exactly(include("name" => "webhookdb.serviceintegration.webhook")),
          "queue" => "webhook",
        ),
      )

      post "/v1/install/intercom/webhook", body

      expect(last_response).to have_status(202)
    end
  end

  describe "post /v1/install/intercom/uninstall" do
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
end
