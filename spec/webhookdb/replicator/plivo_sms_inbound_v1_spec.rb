# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::PlivoSmsInboundV1, :db do
  it_behaves_like "a replicator", supports_row_diff: false do
    let(:sint) do
      Webhookdb::Fixtures.service_integration.create(service_name: "plivo_sms_inbound_v1", backfill_secret: "x")
    end
    let(:body) do
      URI.encode_www_form(JSON.parse(<<~JSON))
        {
          "From": "15306658721",
          "MessageIntent": "",
          "MessageUUID": "b30e9eb8-34bd-11ee-b8b2-0242ac110005",
          "PowerpackUUID": "",
          "Text": "Your BIKETOWN login code is 006766. Never share it with anyone.",
          "To": "12064263986",
          "TotalAmount": "0",
          "TotalRate": "0",
          "Type": "sms",
          "Units": "1"
        }
      JSON
    end
    let(:expected_data) do
      JSON.parse(<<~JSON)
        {
          "From": "15306658721",
          "MessageIntent": "",
          "MessageUUID": "b30e9eb8-34bd-11ee-b8b2-0242ac110005",
          "PowerpackUUID": "",
          "Text": "Your BIKETOWN login code is 006766. Never share it with anyone.",
          "To": "12064263986",
          "TotalAmount": 0,
          "TotalRate": 0,
          "Type": "sms",
          "Units": 1
        }
      JSON
    end
  end

  describe "state machine calculation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "plivo_sms_inbound_v1") }
    let(:svc) { Webhookdb::Replicator.create(sint) }

    describe "calculate_webhook_state_machine" do
      it "asks for auth id" do
        sm = sint.replicator.calculate_webhook_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: "Paste or type your Auth ID here:",
          prompt_is_secret: true,
          post_to_url: end_with("/service_integrations/#{sint.opaque_id}/transition/backfill_key"),
          complete: false,
          output: match("an endpoint to receive Plivo Inbound SMS Messages"),
        )
      end

      it "confirms reciept of auth id, asks for auth token" do
        sint.backfill_key = "myauthid"
        sm = sint.replicator.calculate_webhook_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: "Paste or type your Auth Token here:",
          prompt_is_secret: true,
          post_to_url: end_with("/service_integrations/#{sint.opaque_id}/transition/backfill_secret"),
          complete: false,
          output: "",
        )
      end

      it "validates the auth token, and returns further instructions on success" do
        sint.backfill_key = "myauthid"
        sint.backfill_secret = "myauthtoken"
        req = stub_request(:get, "https://api.plivo.com/v1/Account/myauthid/").
          with(headers: {"Authorization" => "Basic bXlhdXRoaWQ6bXlhdXRodG9rZW4="}).
          to_return(json_response({}))
        sm = sint.replicator.calculate_webhook_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          complete: true,
          output: match("Perfect, those credentials check out."),
        )
        expect(req).to have_been_made
      end

      it "resets auth fields and re-prompts if the auth info is not valid" do
        sint.backfill_key = "myauthid"
        sint.backfill_secret = "myauthtoken"
        sint.save_changes
        req = stub_request(:get, "https://api.plivo.com/v1/Account/myauthid/").
          with(headers: {"Authorization" => "Basic bXlhdXRoaWQ6bXlhdXRodG9rZW4="}).
          to_return(json_response({}, status: 401))
        sm = sint.replicator.calculate_webhook_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: "Paste or type your Auth ID here:",
          prompt_is_secret: true,
          post_to_url: end_with("/service_integrations/#{sint.opaque_id}/transition/backfill_key"),
          complete: false,
          output: include("didn't work (Plivo returned an HTTP 401 error)"),
        )
        expect(req).to have_been_made
        expect(sint.refresh).to have_attributes(backfill_key: "", backfill_secret: "")
      end
    end
  end

  describe "webhook validation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "plivo_sms_inbound_v1") }
    let(:svc) { sint.replicator }

    it "raises an invalid precondition if there is no backfill secret" do
      expect { svc.webhook_response(fake_request) }.to raise_error(Webhookdb::InvalidPrecondition)
    end

    it "returns a 401 for no signature" do
      sint.update(backfill_secret: "abc")
      req = fake_request(input: "To=x&From=y")
      expect(svc.webhook_response(req)).to have_attributes(status: 401, reason: "missing signature")
    end

    it "returns a 401 for no nonce" do
      sint.update(backfill_secret: "abc")
      req = fake_request(input: "To=x&From=y", env: {"HTTP_X_PLIVO_SIGNATURE_V2" => "sig"})
      expect(svc.webhook_response(req)).to have_attributes(status: 401, reason: "missing nonce")
    end

    it "returns a 401 if invalid" do
      sint.update(backfill_secret: "abc")
      req = fake_request(
        input: "To=x&From=y",
        env: {
          "HTTPS" => "on",
          "HTTP_HOST" => "baz.com",
          "PATH_INFO" => "/foo",
          "HTTP_X_PLIVO_SIGNATURE_V2" => "sig",
          "HTTP_X_PLIVO_SIGNATURE_V2_NONCE" => "nonc",
        },
      )
      expect(svc.webhook_response(req)).to have_attributes(status: 401, reason: "invalid signature")
    end

    it "returns ok if valid" do
      sint.update(backfill_secret: "abc")
      req = fake_request(
        input: "To=x&From=y",
        env: {
          "HTTPS" => "on",
          "HTTP_HOST" => "baz.com",
          "PATH_INFO" => "/foo",
          "HTTP_X_PLIVO_SIGNATURE_V2" => "PCEE/ioItYLv1woRasJkIYaOtewFjzuBvy8wBbRNU/w=",
          "HTTP_X_PLIVO_SIGNATURE_V2_NONCE" => "31578143405117776772",
        },
      )
      expect(svc.webhook_response(req)).to have_attributes(status: 202)
    end
  end

  describe "upsert_webhook" do
    let(:sint) do
      Webhookdb::Fixtures.service_integration.create(service_name: "plivo_sms_inbound_v1", webhook_secret: "x")
    end

    before(:each) do
      sint.organization.prepare_database_connections
      sint.replicator.create_table
    end

    after(:each) do
      sint.organization.remove_related_database
    end

    it "can work with the form request" do
      # rubocop:disable Layout/LineLength
      request = Webhookdb::Replicator::WebhookRequest.new(
        body: "From=15306658721&MessageIntent=&MessageUUID=c3959978-34ca-11ee-a537-0242ac110002&PowerpackUUID=&Text=Your+BIKETOWN+login+code+is+824436.+Never+share+it+with+anyone.&To=12064263986&TotalAmount=0&TotalRate=0&Type=sms&Units=1",
        headers: {},
        method: "POST",
        path: "/v1/service_integrations/svi_92ymb7as20af4itb1hmwbogew",
      )
      # rubocop:enable Layout/LineLength
      sint.replicator.upsert_webhook(request)
      expect(sint.replicator.admin_dataset(&:all)).to contain_exactly(
        include(
          from_number: "15306658721",
          data: hash_including("Units" => 1),
        ),
      )
    end
  end
end
