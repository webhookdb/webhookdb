# frozen_string_literal: true

require "webhookdb/api/install"

RSpec.describe Webhookdb::API::Install, :db, reset_configuration: Webhookdb::Customer do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }
  let!(:org) { Webhookdb::Fixtures.organization.create }

  before(:each) do
    Webhookdb::Oauth::FakeProvider.reset
  end

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

    it "302s to forbidden if there is no valid session with the given id" do
      session.update(used_at: Time.now)

      get("/v1/install/fake/callback", state:, code:)

      expect(last_response).to have_status(302)
      expect(last_response.headers).to include("Location" => "/v1/install/fake/forbidden")
    end

    it "shows an error message if the token exchange fails" do
      req = stub_request(:get, "http://fake/").to_return(status: 500)
      Webhookdb::Oauth::FakeProvider.exchange_authorization_code = lambda {
        Webhookdb::Http.get("http://fake", timeout: nil, logger: nil)
      }
      get("/v1/install/fake/callback", state:, code:)
      expect(last_response).to have_status(400)
      expect(req).to have_been_made
      expect(last_response.body).to include("Something went wrong getting your access token from Fake")
    end

    it "updates the session with the exchanged access token and 302s to the login page" do
      Webhookdb::Oauth::FakeProvider.exchange_authorization_code = lambda {
        Webhookdb::Oauth::Tokens.new(access_token: "atok")
      }
      get("/v1/install/fake/callback", code:, state:)
      expect(last_response).to have_status(302)
      expect(last_response.headers).to include("Location" => "/v1/install/fake/login?state=#{state}")
      expect(session.refresh).to have_attributes(token_json: {"access_token" => "atok"}, used_at: nil)
    end
  end

  describe "GET /v1/install/fake_oauth_authorization" do
    it "redirects back to the callback route" do
      get "/v1/install/fake_oauth_authorization", state: "abcd"

      expect(last_response).to have_status(302)
      expect(last_response.headers).to include(
        "Location" => "/v1/install/fake/callback?code=fakecode&state=abcd",
      )
    end
  end

  describe "GET /v1/install/:provider/login" do
    let(:session) { Webhookdb::Fixtures.oauth_session.create }
    let(:state) { session.oauth_state }

    it "renders a form" do
      get("/v1/install/fake/login", state:)

      expect(last_response).to have_status(200)
      expect(last_response.body).to include("finish your sync with")
    end
  end

  describe "POST /v1/install/:provider/login" do
    describe "OTP token param is not present" do
      let(:session) { Webhookdb::Fixtures.oauth_session.create }
      let(:state) { session.oauth_state }

      it "renders login form for existing customer" do
        customer = Webhookdb::Fixtures.customer.create

        post("/v1/install/fake/login", state:, email: customer.email)

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
        customer = Webhookdb::Fixtures.customer.create
        code = Webhookdb::Fixtures.reset_code(customer:).create

        post("/v1/install/fake/login", state:, email: customer.email)

        expect(last_response).to have_status(200)
        expect(code.refresh).to be_expired
        new_code = customer.refresh.reset_codes.first
        expect(new_code).to_not be_expired
        expect(new_code).to have_attributes(transport: "email")
      end

      it "updates the session with customer" do
        customer = Webhookdb::Fixtures.customer.create

        post("/v1/install/fake/login", state:, email: customer.email)

        expect(last_response).to have_status(200)
        expect(session.refresh).to have_attributes(customer: be === customer, used_at: nil)
      end

      it "handles validation failures" do
        post("/v1/install/fake/login", state:, email: "invalid")

        expect(last_response).to have_status(400)
        expect(last_response.body).to include("Email is invalid")
      end
    end

    describe "OTP token param is present" do
      let(:customer) { Webhookdb::Fixtures.customer.create }
      let(:reset_code) { Webhookdb::Fixtures.reset_code(customer:).create }
      let(:otp_token) { reset_code.token }
      let(:email) { customer.email }
      let(:session) { Webhookdb::Fixtures.oauth_session.create(customer:) }
      let(:state) { session.oauth_state }

      it "assigns the customer to the session and redirects to the org chooser" do
        post("/v1/install/fake/login", state:, email:, otp_token:)

        expect(last_response).to have_status(302)
        expect(last_response.headers).to include("Location" => "/v1/install/fake/org?state=#{state}")
        expect(session.refresh).to have_attributes(customer: have_attributes(email:), used_at: nil)
        # Assert default org is created
        expect(Webhookdb::Customer[email:]).to have_attributes(verified_memberships: have_length(1))
      end

      it "skips auth if customer auth should be skipped", reset_configuration: Webhookdb::Customer do
        Webhookdb::Customer.skip_authentication = true
        post("/v1/install/fake/login", state:, email:, otp_token: "invalid token")
        expect(last_response).to have_status(302)
      end

      it "403s if the otp token is invalid" do
        post "/v1/install/fake/login", state:, email:, otp_token: reset_code.token + "1"

        expect(last_response).to have_status(403)
        expect(last_response.body).to include(
          "Sorry, that token is invalid. Please try again.",
        )
      end
    end
  end

  describe "GET /v1/install/:provider/org" do
    let(:customer) { Webhookdb::Fixtures.customer.create }
    let(:session) { Webhookdb::Fixtures.oauth_session.create(customer:) }
    let(:state) { session.oauth_state }

    it "renders a form showing admin memberships" do
      fac = Webhookdb::Fixtures.organization_membership(customer:)
      fac.verified.admin.org(name: "Admin Org").create
      fac.invite.org(name: "Invited Org").create
      fac.verified.org(name: "Member Org").create

      get("/v1/install/fake/org", state:)

      expect(last_response).to have_status(200)
      expect(last_response.body).to include("Admin Org")
      expect(last_response.body).to_not include("Invited Org")
      expect(last_response.body).to_not include("Member Org")
    end
  end

  describe "POST /v1/install/:provider/org" do
    let(:customer) { Webhookdb::Fixtures.customer.create }
    let(:session) { Webhookdb::Fixtures.oauth_session.create(customer:, token_json: {"access_token" => "atok"}) }
    let(:state) { session.oauth_state }

    it "errors if org key and name are not present" do
      post("/v1/install/fake/org", state:)

      expect(last_response).to have_status(400)
      expect(last_response.body).to include("or a new organization name are required")
    end

    describe "with a new org name" do
      it "creates the org, sets it as the user default, creates the database, and creates replicators" do
        old_default = Webhookdb::Fixtures.organization_membership.verified.default.create(customer:)

        post("/v1/install/fake/org", state:, new_org_name: "Hello", existing_org_key: "")

        expect(last_response).to have_status(302)
        expect(last_response.headers).to include("Location" => "/v1/install/fake/success?state=#{state}")
        new_org = Webhookdb::Organization[name: "Hello"]
        expect(new_org.service_integrations).to contain_exactly(have_attributes(service_name: "fake_v1"))
        expect(customer.verified_memberships_dataset[organization: new_org]).to be_default
        expect(new_org.admin_connection { |db| db.select(1).first }).to eq({"?column?": 1})
        expect(old_default.refresh).to_not be_default
        expect(session.refresh).to have_attributes(
          used_at: nil,
          customer: be === customer,
          organization: be === new_org,
          token_json: nil,
        )
      end

      it "errors if an org with that name exists" do
        Webhookdb::Fixtures.organization.create(name: "Hi")

        post("/v1/install/fake/org", state:, new_org_name: "Hi")

        expect(last_response).to have_status(400)
        expect(last_response.body).to include("with that name already exists")
      end
    end

    describe "with an existing org key" do
      it "creates the replicators in the given org and sets it as a default" do
        old_default = Webhookdb::Fixtures.organization_membership.verified.default.create(customer:)
        other_membership = Webhookdb::Fixtures.organization_membership.verified.admin.create(customer:)
        other_org = other_membership.organization.refresh

        post("/v1/install/fake/org", state:, existing_org_key: other_org.key)

        expect(last_response).to have_status(302)
        expect(last_response.headers).to include("Location" => "/v1/install/fake/success?state=#{state}")
        other_org.refresh
        expect(other_org.service_integrations).to contain_exactly(have_attributes(service_name: "fake_v1"))
        expect(other_org.admin_connection { |db| db.select(1).first }).to eq({"?column?": 1})
        expect(other_membership.refresh).to be_default
        expect(old_default.refresh).to_not be_default
        expect(session.refresh).to have_attributes(
          used_at: nil,
          customer: be === customer,
          organization: be === other_org,
          token_json: nil,
        )
      end

      it "errors if the customer is not a verified member of the org" do
        org = Webhookdb::Fixtures.organization_membership.verified.admin.create.organization

        post("/v1/install/fake/org", state:, existing_org_key: org.key)

        expect(last_response).to have_status(400)
        expect(last_response.body).to include("or it does not exist")
      end

      it "errors if the customer is not an admin of the org" do
        org = Webhookdb::Fixtures.organization_membership.verified.create(customer:).organization

        post("/v1/install/fake/org", state:, existing_org_key: org.key)

        expect(last_response).to have_status(400)
        expect(last_response.body).to include("or it does not exist")
      end
    end
  end

  describe "GET /v1/install/:provider/success" do
    let(:customer) { Webhookdb::Fixtures.customer.create }
    let(:organization) { Webhookdb::Fixtures.organization.with_urls.create }
    let(:session) { Webhookdb::Fixtures.oauth_session.create(customer:, organization:) }
    let(:state) { session.oauth_state }

    it "renders a success form and marks the session used" do
      get("/v1/install/fake/success", state:)

      expect(last_response).to have_status(200)
      expect(last_response).to have_status(200)
      expect(last_response.body).to include(
        "We are now listening for updates to resources in your Fake account.",
      )
      expect(last_response.body).to include(organization.readonly_connection_url)
      expect(session.refresh).to have_attributes(used_at: match_time(:now))
    end

    it "modifies the success page if webhooks are not supported" do
      Webhookdb::Oauth::FakeProvider.supports_webhooks = proc { false }
      get("/v1/install/fake/success", state:)
      expect(last_response).to have_status(200)
      expect(last_response.body).to include(
        "We are now checking for updates to resources in your Fake account",
      )
    end

    it "redirects to /forbidden if the session is invalid/used" do
      session.update(used_at: Time.now)
      get("/v1/install/fake/success", state:)
      expect(last_response).to have_status(302)
      expect(last_response.headers).to include("Location" => "/v1/install/fake/forbidden")
    end
  end

  describe "GET /v1/install/:provider/forbidden" do
    it "renders a page" do
      get("/v1/install/fake/forbidden")

      expect(last_response).to have_status(403)
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

    it "noops if there is no resource url" do
      body.delete("payload")

      post "/v1/install/front/webhook", body

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(message: "unregistered/empty app")
      expect(Webhookdb::LoggedWebhook.all).to contain_exactly(
        include(service_integration_opaque_id: start_with("front_marketplace_host-?")),
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
            external_id: "msg_55c8c149-+13334445555",
            external_conversation_id: "+13334445555",
          )
        end
      end
    end
  end

  describe "POST /v1/install/increase/webhook" do
    let(:event_body) do
      {
        associated_object_id: "account_in71c4amph0vgo2qllky",
        associated_object_type: "account",
        category: "account.created",
        created_at: "2020-01-31T23:59:59Z",
        id: "event_001dzz0r20rzr4zrhrr1364hy80",
        type: "event",
      }
    end
    let(:sig_header) do
      Webhookdb::Increase.compute_signature(
        data: event_body.to_json,
        secret: Webhookdb::Increase.webhook_secret,
        t: Time.now,
      ).format
    end

    it "handles as a platform event if there is no Increase-Group-Id header", :async do
      header "Increase-Webhook-Signature", sig_header

      expect do
        post "/v1/install/increase/webhook", event_body

        expect(last_response).to have_status(202)
        expect(last_response).to have_json_body.that_includes(message: "ok")
      end.to publish("increase.account.created").
        with_payload([event_body.merge({"created_at" => "2020-01-31T23:59:59.000Z"}).as_json])
    end

    it "logs and returns if the group is not found" do
      header "Increase-Webhook-Signature", sig_header
      header "Increase-Group-Id", "xyz"

      post "/v1/install/increase/webhook", event_body

      expect(last_response).to have_status(202)
      expect(last_response).to have_json_body.that_includes(message: "unregistered group")
    end

    it "performs webhook verification" do
      Webhookdb::Fixtures.service_integration.create(service_name: "increase_app_v1", api_url: "mygroup")
      header "Increase-Group-Id", "mygroup"

      post "/v1/install/increase/webhook", event_body
      expect(last_response).to have_status(401)

      header "Increase-Webhook-Signature", "abc"
      post "/v1/install/increase/webhook", event_body
      expect(last_response).to have_status(401)

      header "Increase-Webhook-Signature", sig_header
      post "/v1/install/increase/webhook", event_body
      expect(last_response).to have_status(202)
    end

    it "handles the event" do
      org = Webhookdb::Fixtures.organization.create
      fac = Webhookdb::Fixtures.service_integration(organization: org)
      root = fac.create(service_name: "increase_app_v1", api_url: "mygroup")
      event = fac.create(service_name: "increase_event_v1", depends_on: root)

      org.prepare_database_connections
      event.replicator.create_table

      header "Increase-Group-Id", "mygroup"
      header "Increase-Webhook-Signature", sig_header

      post "/v1/install/increase/webhook", event_body

      expect(last_response).to have_status(202)
      expect(event.replicator.admin_dataset(&:all)).to have_length(1)
    ensure
      org.remove_related_database
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
      org.prepare_database_connections
      root = Webhookdb::Fixtures.service_integration.create(
        service_name: "intercom_marketplace_root_v1",
        api_url: "ghi567",
        organization: org,
      )
      fac = Webhookdb::Fixtures.service_integration(organization: org).depending_on(root)
      fac.create(service_name: "intercom_contact_v1")
      fac.create(service_name: "intercom_conversation_v1")

      post "/v1/install/intercom/uninstall", {app_id: "ghi567"}
      expect(last_response).to have_status(200)
      expect(org.refresh.service_integrations).to be_empty
    ensure
      org.remove_related_database
    end

    it "noops if the integration does not exist" do
      post "/v1/install/intercom/uninstall", {app_id: "ghi567"}

      expect(last_response).to have_status(200)
    end

    it "logs the webhook headers properly (tests handle_webhook_request)" do
      post "/v1/install/intercom/uninstall", {app_id: "ghi567"}

      expect(last_response).to have_status(200)

      # This tests handle_webhook_request with a block returning :pass.
      # We can test it directly in the future but this is good enough for now.
      expect(Webhookdb::LoggedWebhook.first).to have_attributes(
        request_path: "/v1/install/intercom/uninstall",
        request_headers: include("host", "version", "trace-id"),
      )
    end
  end

  describe "POST /v1/install/intercom/health" do
    it "returns 'OK' status if the integration exists" do
      Webhookdb::Fixtures.service_integration.create(
        service_name: "intercom_marketplace_root_v1", api_url: "apple_banana",
      )

      post "/v1/install/intercom/health", {workspace_id: "apple_banana"}
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(state: "OK")
    end

    it "returns UNHEALTHY if the integration does not exist" do
      post "/v1/install/intercom/health", {workspace_id: "apple_banana"}
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(state: "UNHEALTHY", cta_type: "REINSTALL_CTA")
    end
  end
end
