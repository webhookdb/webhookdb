# frozen_string_literal: true

require "support/shared_examples_for_services"

RSpec.describe Webhookdb::Services::PlaidItemV1, :db do
  it_behaves_like "a service implementation", "plaid_item_v1" do
    let(:body) do
      JSON.parse(<<~J)
                {
          "webhook_type": "ITEM",
          "webhook_code": "PENDING_EXPIRATION",
          "item_id": "wz666MBjYWTp2PDzzggYhM6oWWmBb",
          "consent_expiration_time": "2020-01-15T13:25:17.766Z"
        }
      J
    end
    let(:expected_data) { {"item_id" => "wz666MBjYWTp2PDzzggYhM6oWWmBb"} }
    let(:supports_row_diff) { false }
  end

  it_behaves_like "a service implementation with dependents", "plaid_item_v1", "plaid_transaction_v1" do
    let(:body) do
      JSON.parse(<<~J)
        {
          "webhook_type": "ITEM",
          "webhook_code": "PENDING_EXPIRATION",
          "item_id": "wz666MBjYWTp2PDzzggYhM6oWWmBb",
          "consent_expiration_time": "2020-01-15T13:25:17.766Z"
        }
      J
    end
    let(:expected_insert) do
      {
        consent_expiration_time: "2020-01-15T13:25:17.766Z",
        data: {item_id: "wz666MBjYWTp2PDzzggYhM6oWWmBb"}.to_json,
        plaid_id: "wz666MBjYWTp2PDzzggYhM6oWWmBb",
      }
    end
    let(:can_track_row_changes) { false }
  end

  describe "upsert_webhook" do
    let(:sint) do
      Webhookdb::Fixtures.service_integration.stable_encryption_secret.create(service_name: "plaid_item_v1")
    end
    let(:svc) { Webhookdb::Services.service_instance(sint) }

    before(:each) do
      sint.organization.prepare_database_connections
      svc.create_table
    end

    after(:each) do
      sint.organization.remove_related_database
    end

    it "sets error on error webhooks" do
      body = JSON.parse(<<~J)
        {
          "webhook_type": "ITEM",
          "webhook_code": "USER_PERMISSION_REVOKED",
          "error": {
            "error_code": "USER_PERMISSION_REVOKED",
            "error_message": "the holder of this account has revoked their permission for your application to access it",
            "error_type": "ITEM_ERROR",
            "status": 400
          },
          "item_id": "gAXlMgVEw5uEGoQnnXZ6tn9E7Mn3LBc4PJVKZ"
        }
      J
      svc.upsert_webhook(body:)
      expect(svc.readonly_dataset(&:all)).to contain_exactly(include(:error))
      expect(svc.readonly_dataset(&:all).first[:error].to_h).to include("error_code" => "USER_PERMISSION_REVOKED")
    end

    it "sets consent_expiration_time on consent webhooks" do
      body = JSON.parse(<<~J)
        {
          "webhook_type": "ITEM",
          "webhook_code": "PENDING_EXPIRATION",
          "item_id": "wz666MBjYWTp2PDzzggYhM6oWWmBb",
          "consent_expiration_time": "2020-01-15T13:25:17.766Z"
        }
      J
      svc.upsert_webhook(body:)
      expect(svc.readonly_dataset(&:all)).to contain_exactly(
        include(
          consent_expiration_time: match_time("2020-01-15T13:25:17.766Z"),
        ),
      )
    end

    it "fetches on created webhooks and encrypts the token" do
      plaid_body = <<~J
        {
          "item": {
            "available_products": [
              "balance",
              "auth"
            ],
            "billed_products": [
              "identity",
              "transactions"
            ],
            "error": null,
            "institution_id": "ins_109508",
            "item_id": "wz666MBjYWTp2PDzzggYhM6oWWmBb",
            "update_type": "background",
            "webhook": "https://plaid.com/example/hook",
            "consent_expiration_time": null
          },
          "status": {
            "transactions": {
              "last_successful_update": "2019-02-15T15:52:39Z",
              "last_failed_update": "2019-01-22T04:32:00Z"
            },
            "last_webhook": {
              "sent_at": "2019-02-15T15:53:00Z",
              "code_sent": "DEFAULT_UPDATE"
            }
          },
          "request_id": "m8MDnv9okwxFNBV"
        }
      J
      sint.backfill_key = "clid"
      sint.backfill_secret = "rune"
      req = stub_request(:post, "https://fake-url.com/item/get").
        with(body: {access_token: "atok", client_id: "clid", secret: "rune"}.to_json).
        to_return(status: 200, body: plaid_body, headers: {"Content-Type" => "application/json"})

      body = JSON.parse(<<~J)
        {
          "webhook_type": "ITEM",
          "webhook_code": "CREATED",
          "item_id": "wz666MBjYWTp2PDzzggYhM6oWWmBb",
          "access_token": "atok"
        }
      J
      svc.upsert_webhook(body:)
      expect(svc.readonly_dataset(&:all)).to contain_exactly(
        include(
          plaid_id: "wz666MBjYWTp2PDzzggYhM6oWWmBb",
          institution_id: "ins_109508",
          encrypted_access_token: "amIg507BPydo1vl3B3Tn9g==",
        ),
      )
      expect(req).to have_been_made
    end

    it "marks the item as errored if removed" do
      plaid_body = <<~J
        {
          "display_message": null,
          "documentation_url": "https://plaid.com/docs/?ref=error#item-errors",
          "error_code": "ITEM_NOT_FOUND",
          "error_message": "The Item you requested cannot be found. This Item does not exist, has been previously removed via /item/remove, or has had access removed by the user.",
          "error_type": "ITEM_ERROR",
          "request_id": "cOGnMlnwqacoUpr",
          "suggested_action": null
        }
      J
      req = stub_request(:post, "https://fake-url.com/item/get").
        to_return(status: 400, body: plaid_body, headers: {"Content-Type" => "application/json"})

      body = JSON.parse(<<~J)
        {
          "webhook_type": "ITEM",
          "webhook_code": "CREATED",
          "item_id": "wz666MBjYWTp2PDzzggYhM6oWWmBb",
          "access_token": "atok"
        }
      J
      svc.upsert_webhook(body:)
      expect(svc.readonly_dataset(&:all)).to contain_exactly(
        include(plaid_id: "wz666MBjYWTp2PDzzggYhM6oWWmBb", encrypted_access_token: "amIg507BPydo1vl3B3Tn9g=="),
      )
      expect(svc.readonly_dataset(&:first)[:error].as_json).to(include("error_code" => "ITEM_NOT_FOUND"))
      expect(req).to have_been_made
    end

    it "notifies dependents on non-item webhook types" do
      svc.admin_dataset do |ds|
        ds.insert(plaid_id: "wz666MBjYWTp2PDzzggYhM6oWWmBb", data: "{}")
      end
      body = JSON.parse(<<~J)
        {
          "webhook_type": "TRANSACTIONS",
          "webhook_code": "INITIAL_UPDATE",
          "item_id": "wz666MBjYWTp2PDzzggYhM6oWWmBb",
          "error": null
        }
      J
      dep = Webhookdb::Fixtures.service_integration.
        depending_on(sint).
        create(organization: sint.organization, service_name: "plaid_transaction_v1")
      expect(sint.dependents.first).to be === dep
      dep_svc = sint.dependents.first.service_instance
      dep_svc.create_table
      expect(sint.dependents.first).to receive(:service_instance).and_return(dep_svc)
      expect(dep_svc).to receive(:handle_incremental_update)

      svc.upsert_webhook(body:)
    end
  end

  describe "webhook validation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "plaid_item_v1") }
    let(:svc) { Webhookdb::Services.service_instance(sint) }

    it "uses Plaid webhook responder" do
      req = fake_request
      expect(Webhookdb::Plaid).to receive(:webhook_response).and_call_original
      status, _headers, _body = svc.webhook_response(req)
      expect(status).to eq(401)
    end
  end

  describe "state machine calculation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "plaid_item_v1") }
    let(:svc) { Webhookdb::Services.service_instance(sint) }

    describe "process_state_change" do
      it "uses a default api url if value is blank" do
        sint.process_state_change("api_url", "")
        expect(sint.api_url).to eq("https://production.plaid.com")
      end

      it "guesses the url" do
        sint.process_state_change("api_url", "development")
        expect(sint.api_url).to eq("https://development.plaid.com")
        sint.process_state_change("api_url", "https://sandbox.plaid.com/")
        expect(sint.api_url).to eq("https://sandbox.plaid.com")
        sint.process_state_change("api_url", "Production")
        expect(sint.api_url).to eq("https://production.plaid.com")
      end
    end

    describe "calculate_create_state_machine" do
      it "sets the encryption secret and prompts for a webhook secret" do
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: "Paste or type your secret here:",
          prompt_is_secret: true,
          post_to_url: end_with("/transition/webhook_secret"),
          complete: false,
          output: match("You are about to add support for adding Plaid Items").and(match("generate a secret")),
        )
      end

      it "prompts if api_url is not set" do
        sint.webhook_secret = "abc"
        sint.api_url = ""
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: "Paste or type your API host here:",
          prompt_is_secret: false,
          post_to_url: end_with("/transition/api_url"),
          output: match("Great. Now we want to make sure we're sending API requests to the right place."),
        )
      end

      it "prompts for backfill key" do
        sint.webhook_secret = "abc"
        sint.api_url = "https://foo"
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: "Paste or type your Plaid Client ID here:",
          prompt_is_secret: false,
          post_to_url: end_with("/transition/backfill_key"),
          output: match("Almost there. We will need to use the Plaid API"),
        )
      end

      it "prompts for backfill secret" do
        sint.webhook_secret = "abc"
        sint.api_url = "https://foo"
        sint.backfill_key = "sek"
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: "Paste or type your Plaid Secret here:",
          prompt_is_secret: true,
          post_to_url: end_with("/transition/backfill_secret"),
          output: match("And now your API secret, too."),
        )
      end

      it "prints an existing webhook secret if it is set" do
        sint.webhook_secret = "whsec_abcasdf"
        sint.api_url = "https://foo"
        sint.backfill_key = "bk"
        sint.backfill_secret = "sekrit"
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          prompt: "",
          prompt_is_secret: false,
          post_to_url: "",
          complete: true,
          output: match("Excellent. We have made a URL available"),
        )
      end
    end

    describe "calculate_backfill_state_machine" do
      it "returns the create state machine" do
        sm = sint.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          output: match("You are about to add support"),
        )
      end
    end
  end
end
