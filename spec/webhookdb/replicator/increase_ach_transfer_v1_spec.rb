# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::IncreaseACHTransferV1, :db do
  it_behaves_like "a replicator", "increase_ach_transfer_v1" do
    let(:body) do
      JSON.parse(<<~J)
        {
          "event_id": "transfer_event_123",
          "event": "created",
          "created_at": "2020-01-31T23:59:59Z",
          "data": {
            "account_number": "987654321",
            "account_id": "account_f654119657",
            "amount": 100,
            "approval": {
              "approved_at": "2020-01-31T23:59:59Z",
              "approved_by": "user@example.com"
            },
            "cancellation": {},
            "created_at": "2020-01-31T23:59:59Z",
            "id": "ach_transfer_uoxatyh3lt5evrsdvo7q",
            "network": "ach",
            "path": "/transfers/achs/ach_transfer_uoxatyh3lt5evrsdvo7q",
            "return": {},
            "routing_number": "123456789",
            "statement_descriptor": "Statement descriptor",
            "status": "returned",
            "submission": {},
            "template_id": "ach_transfer_template_wofoi8uhkjzi5rubh3kt",
            "transaction_id": "transaction_uyrp7fld2ium70oa7oi",
            "addendum": null,
            "notification_of_change": null
          }
        }
      J
    end
    let(:expected_data) { body["data"] }
  end

  it_behaves_like "a replicator that prevents overwriting new data with old",
                  "increase_ach_transfer_v1" do
    let(:old_body) do
      JSON.parse(<<~J)
        {
          "event_id": "transfer_event_123",
          "event": "created",
          "created_at": "2020-01-31T23:59:59Z",
          "data": {
            "account_number": "987654321",
            "account_id": "account_566f1f672175",
            "amount": 100,
            "approval": {
              "approved_at": "2020-01-31T23:59:59Z",
              "approved_by": "user@example.com"
            },
            "cancellation": {},
            "created_at": "2020-01-31T23:59:59Z",
            "id": "ach_transfer_uoxatyh3lt5evrsdvo7q",
            "network": "ach",
            "path": "/transfers/achs/ach_transfer_uoxatyh3lt5evrsdvo7q",
            "return": {},
            "routing_number": "123456789",
            "statement_descriptor": "Statement descriptor",
            "status": "returned",
            "submission": {},
            "template_id": "ach_transfer_template_wofoi8uhkjzi5rubh3kt",
            "transaction_id": "transaction_uyrp7fld2ium70oa7oi",
            "addendum": null,
            "notification_of_change": null
          }
        }
      J
    end
    let(:new_body) do
      JSON.parse(<<~J)
        {
          "event_id": "transfer_event_456",
          "event": "updated",
          "created_at": "2020-02-20T23:59:59Z",
          "data": {
            "account_number": "987654321",
            "account_id": "account_6d9543f8492d",
            "amount": 100,
            "approval": {
              "approved_at": "2020-01-31T23:59:59Z",
              "approved_by": "user@example.com"
            },
            "cancellation": {},
            "created_at": "2020-01-10T23:59:59Z",
            "id": "ach_transfer_uoxatyh3lt5evrsdvo7q",
            "network": "ach",
            "path": "/transfers/achs/ach_transfer_uoxatyh3lt5evrsdvo7q",
            "return": {},
            "routing_number": "123456789",
            "statement_descriptor": "Statement descriptor",
            "status": "returned",
            "submission": {},
            "template_id": "ach_transfer_template_wofoi8uhkjzi5rubh3kt",
            "transaction_id": "transaction_uyrp7fld2ium70oa7oi",
            "addendum": null,
            "notification_of_change": null
          }
        }
      J
    end
    let(:expected_old_data) { old_body["data"] }
    let(:expected_new_data) { new_body["data"] }
  end

  it_behaves_like "a replicator that deals with resources and wrapped events",
                  "increase_ach_transfer_v1" do |_name|
    let(:resource_json) { resource_in_envelope_json.fetch("data") }
    let(:resource_in_envelope_json) do
      JSON.parse(<<~J)
        {
          "event_id": "transfer_event_123",
          "event": "created",
          "created_at": "2020-01-31T23:59:59Z",
          "data": {
            "account_number": "987654321",
            "account_id": "account_566f1f672175",
            "amount": 100,
            "approval": {
              "approved_at": "2020-01-31T23:59:59Z",
              "approved_by": "user@example.com"
            },
            "cancellation": {},
            "created_at": "2020-01-31T23:59:59Z",
            "id": "ach_transfer_uoxatyh3lt5evrsdvo7q",
            "network": "ach",
            "path": "/transfers/achs/ach_transfer_uoxatyh3lt5evrsdvo7q",
            "return": {},
            "routing_number": "123456789",
            "statement_descriptor": "Statement descriptor",
            "status": "returned",
            "submission": {},
            "template_id": "ach_transfer_template_wofoi8uhkjzi5rubh3kt",
            "transaction_id": "transaction_uyrp7fld2ium70oa7oi",
            "addendum": null,
            "notification_of_change": null
          }
        }
      J
    end
  end

  it_behaves_like "a replicator that verifies backfill secrets" do
    let(:correct_creds_sint) do
      Webhookdb::Fixtures.service_integration.create(
        service_name: "increase_ach_transfer_v1",
        backfill_key: "bfkey",
        api_url: "https://api.increase.com",
      )
    end
    let(:incorrect_creds_sint) do
      Webhookdb::Fixtures.service_integration.create(
        service_name: "increase_ach_transfer_v1",
        backfill_key: "bfkey_wrong",
        api_url: "https://api.increase.com",
      )
    end

    let(:success_body) do
      <<~R
        {
          "data": [],
          "response_metadata": {}
        }
      R
    end
    def stub_service_request
      return stub_request(:get, "https://api.increase.com/transfers/achs").
          with(headers: {"Authorization" => "Bearer bfkey"}).
          to_return(status: 200, body: success_body, headers: {})
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.increase.com/transfers/achs").
          with(headers: {"Authorization" => "Bearer bfkey_wrong"}).
          to_return(status: 401, body: "", headers: {})
    end
  end

  it_behaves_like "a replicator that can backfill", "increase_ach_transfer_v1" do
    # We are specifying the :api_url value because it gets used in the backfill process
    let(:api_url) { "https://api.increase.com" }
    let(:page1_response) do
      <<~R
        {
          "data": [
            {
              "id": "ach_transfer_svhkxlygh3pqwuiwxr4p",
              "statement_descriptor": "Lithic Tech",
              "account_id": "account_0ccdf68f2929",
              "amount": -25000,
              "account_number": "283589779",
              "routing_number": "123456789",
              "return": {
                "created_at": "2021-08-19T19:25:05Z",
                "return_reason_code": "insufficient_fund"
              },
              "created_at": "2021-08-17T19:05:15Z",
              "network": "ach",
              "path": "/transfers/achs/ach_transfer_svhkxlygh3pqwuiwxr4p",
              "status": "returned",
              "submission": {
                "trace_number": "053112920088161"
              },
              "transaction_id": "transaction_qrejyflufbtax3zaejbp"
            },
            {
              "id": "ach_transfer_tblriydrv5eyaane8kf7",
              "statement_descriptor": "Refund for Boom Fees #576",
              "account_id": "account_d432c40f506c",
              "amount": 2000,
              "account_number": "80007991278",
              "routing_number": "123456789",
              "created_at": "2021-08-17T07:49:07Z",
              "network": "ach",
              "path": "/transfers/achs/ach_transfer_tblriydrv5eyaane8kf7",
              "status": "submitted",
              "submission": {
                "trace_number": "053112920088162"
              },
              "transaction_id": "transaction_4hfmdlbizqalyak0vhvy"
            }
          ],
          "response_metadata": {
            "next_cursor": "aW1pdCI6Mn0sInBvc2l0aW9uIjp7Im9mZnNldCI6NH19"
          }
        }
      R
    end
    let(:page2_response) do
      <<~R
        {
          "data": [
            {
              "id": "ach_transfer_9gpkg2iab2mvqolj3m6v",
              "statement_descriptor": "Lithic Tech",
              "account_id": "account_55eb04b7f613",
              "amount": -89194,
              "account_number": "28599037",
              "routing_number": "123456789",
              "created_at": "2021-08-16T06:05:17Z",
              "network": "ach",
              "path": "/transfers/achs/ach_transfer_9gpkg2iab2mvqolj3m6v",
              "status": "submitted",
              "submission": {
                "trace_number": "053112920021490"
              },
              "transaction_id": "transaction_dp1nktbjmocrl4doinbs"
            },
            {
              "id": "ach_transfer_tsqnxiny4lb5ppg0ercb",
              "statement_descriptor": "Lithic Tech",
              "account_id": "account_e387048222e1",
              "amount": -88402,
              "account_number": "1466572",
              "routing_number": "123456789",
              "return": {
                "created_at": "2021-08-17T15:11:08Z",
                "return_reason_code": "insufficient_fund"
              },
              "created_at": "2021-08-16T05:05:38Z",
              "network": "ach",
              "path": "/transfers/achs/ach_transfer_tsqnxiny4lb5ppg0ercb",
              "status": "returned",
              "submission": {
                "trace_number": "053112920021492"
              },
              "transaction_id": "transaction_ehcs1vylp3koisigf7xw"
            }
          ],
          "response_metadata": {
            "next_cursor": "lpYUWlPako5ZlEiLCJsaW1pdCI6Mn0sInBvc2l0aW9uIjp7Im9mZnNldCI6Nn19"
          }
        }
      R
    end
    let(:page3_response) do
      <<~R
        {
          "data": [],
          "response_metadata": {
            "next_cursor": null
          }
        }
      R
    end
    let(:expected_items_count) { 4 }
    def stub_service_requests
      return [
        stub_request(:get, "https://api.increase.com/transfers/achs").
            with(headers: {"Authorization" => "Bearer bfkey"}).
            to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://api.increase.com/transfers/achs?cursor=aW1pdCI6Mn0sInBvc2l0aW9uIjp7Im9mZnNldCI6NH19").
            to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://api.increase.com/transfers/achs?cursor=lpYUWlPako5ZlEiLCJsaW1pdCI6Mn0sInBvc2l0aW9uIjp7Im9mZnNldCI6Nn19").
            to_return(status: 200, body: page3_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_empty_requests
      return [
        stub_request(:get, "https://api.increase.com/transfers/achs").
            to_return(status: 200, body: page3_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.increase.com/transfers/achs").
          to_return(status: 500, body: "gah")
    end
  end

  describe "webhook validation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "increase_ach_transfer_v1") }
    let(:svc) { Webhookdb::Replicator.create(sint) }

    it "returns a 401 as per spec if there is no Authorization header" do
      req = fake_request
      status, _headers, _body = svc.webhook_response(req).to_rack
      expect(status).to eq(401)
    end

    it "returns a 401 for an invalid Authorization header" do
      sint.update(webhook_secret: "user:pass")
      req = fake_request(input: '{"data": "asdfghujkl"}')
      data = req.body
      computed_auth = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), "user:pass", '{"data": "foobar"}')
      req.add_header("HTTP_X_BANK_WEBHOOK_SIGNATURE", "sha256=" + computed_auth)
      status, _headers, body = svc.webhook_response(req).to_rack
      expect(status).to eq(401)
      expect(body).to include("invalid hmac")
    end

    it "returns a 202 with a valid Authorization header" do
      sint.update(webhook_secret: "user:pass")
      req = fake_request(input: '{"data": "asdfghujkl"}')
      data = req.body
      computed_auth = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), "user:pass", data)
      req.add_header("HTTP_X_BANK_WEBHOOK_SIGNATURE", "sha256=" + computed_auth)
      status, _headers, _body = svc.webhook_response(req).to_rack
      expect(status).to eq(202)
    end
  end

  describe "state machine calculation" do
    let(:sint) do
      # Set api url to empty string so that backfill flow works correctly for testing purposes
      Webhookdb::Fixtures.service_integration.create(service_name: "increase_ach_transfer_v1", api_url: "")
    end
    let(:svc) { Webhookdb::Replicator.create(sint) }

    describe "process_state_change" do
      it "uses a default api url if value is blank" do
        sint.replicator.process_state_change("api_url", "")
        expect(sint.api_url).to eq("https://api.increase.com")
      end
    end

    describe "calculate_webhook_state_machine" do
      it "asks for webhook secret" do
        sm = sint.replicator.calculate_webhook_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: "Paste or type your secret here:",
          prompt_is_secret: true,
          post_to_url: end_with("/service_integrations/#{sint.opaque_id}/transition/webhook_secret"),
          complete: false,
          output: match("We've made an endpoint available for Increase ACH Transfer webhooks:"),
        )
      end

      it "confirms reciept of webhook secret, returns org database info" do
        sint.webhook_secret = "whsec_abcasdf"
        sm = sint.replicator.calculate_webhook_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          prompt: "",
          prompt_is_secret: false,
          post_to_url: "",
          complete: true,
          output: match("Great! WebhookDB is now listening for Increase ACH Transfer webhooks."),
        )
      end
    end

    describe "calculate_backfill_state_machine" do
      let(:success_body) do
        <<~R
          {
            "data": [],
            "response_metadata": {}
          }
        R
      end

      def stub_service_request
        return stub_request(:get, "https://api.increase.com/transfers/achs").
            with(headers: {"Authorization" => "Bearer bfkey"}).
            to_return(status: 200, body: success_body, headers: {})
      end

      it "asks for backfill key" do
        sm = sint.replicator.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: "Paste or type your API Key here:",
          prompt_is_secret: true,
          post_to_url: end_with("/service_integrations/#{sint.opaque_id}/transition/backfill_key"),
          complete: false,
          output: match("In order to backfill Increase ACH Transfers, we need an API key."),
        )
      end

      it "asks for api url" do
        sint.backfill_key = "bfkey"
        sm = sint.replicator.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: "Paste or type your API url here:",
          prompt_is_secret: false,
          post_to_url: end_with("/service_integrations/#{sint.opaque_id}/transition/api_url"),
          complete: false,
          output: match("Now we want to make sure we're sending API requests to the right place"),
        )
      end

      it "confirms reciept of api url, returns org database info" do
        sint.backfill_key = "bfkey"
        sint.api_url = "https://api.increase.com"
        res = stub_service_request
        sm = sint.replicator.calculate_backfill_state_machine
        expect(res).to have_been_made
        expect(sm).to have_attributes(
          needs_input: false,
          prompt: "",
          prompt_is_secret: false,
          post_to_url: "",
          complete: true,
          output: match("Great! We are going to start backfilling your Increase ACH Transfers."),
        )
      end
    end
  end

  it_behaves_like "a replicator that upserts webhooks only under specific conditions",
                  "increase_ach_transfer_v1" do
    let(:incorrect_webhook) do
      JSON.parse(<<~J)
        {
          "event_id": "transaction_event_123",
          "event": "created",
          "created_at": "2020-01-31T23:59:59Z",
          "data": {
            "id": "transaction_uyrp7fld2ium70oa7oi",
            "account_id": "account_in71c4amph0vgo2qllky",
            "amount": 100,
            "date": "2020-01-10",
            "description": "Rent payment",
            "route_id": "ach_route_yy0yirrxa4pblzl0k4op",
            "path": "/transactions/transaction_uyrp7fld2ium70oa7oi",
            "source": {}
          }
        }
      J
    end
  end

  describe "upsert behavior" do
    Webhookdb::SpecHelpers::Whdb.setup_upsert_webhook_example(self)
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "increase_ach_transfer_v1") }
    let(:svc) { sint.replicator }

    before(:each) do
      sint.organization.prepare_database_connections
    end

    after(:each) do
      sint.organization.remove_related_database
    end

    it "ignores inbound_ach_transfer events" do
      body = JSON.parse(<<~J)
        {
          "created_at": "2023-09-05T01:34:08Z",
          "event_id": "notification_event_npt3dixtzucfpkthngme",
          "event": "updated",
          "data": {
            "id": "ach_transfer_uoxatyh3lt5evrsdvo7q",
            "amount": 200,
            "direction": "debit",
            "status": "accepted",
            "originator_company_name": "LIVIN PROPERTIES",
            "originator_company_descriptive_date": "230902",
            "originator_company_discretionary_data": null,
            "originator_company_entry_description": "281074-109",
            "originator_company_id": "3101473643",
            "receiver_id_number": "111-222-7777",
            "receiver_name": "SOME NAME",
            "trace_number": "091000022460078",
            "automatically_resolves_at": "2023-09-05T01:33:12Z",
            "acceptance": {
              "accepted_at": "2023-09-05T01:34:07Z",
              "transaction_id": "transaction_w3nabeqojrqvitt9gdf4"
            },
            "decline": null,
            "transfer_return": null,
            "notification_of_change": null,
            "type": "inbound_ach_transfer"
          }
        }
      J
      svc.create_table
      upsert_webhook(svc, body:)
      expect(svc.readonly_dataset(&:all)).to be_empty
    end
  end
end
