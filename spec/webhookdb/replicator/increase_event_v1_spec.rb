# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::IncreaseEventV1, :db do
  it_behaves_like "a replicator", "increase_event_v1" do
    let(:body) { JSON.parse(<<~JSON) }
      {
        "id": "event_123abc",
        "created_at": "2020-01-31T23:59:59Z",
        "category": "transaction.created",
        "associated_object_type": "transaction",
        "associated_object_id": "transaction_abc123",
        "type": "event"
      }
    JSON
  end

  it_behaves_like "a replicator that prevents overwriting new data with old", "increase_event_v1" do
    let(:old_body) { JSON.parse(<<~JSON) }
      {
        "id": "transfer_event_123",
        "created_at": "2020-01-31T23:59:59Z",
        "category": "transaction.created",
        "associated_object_type": "transaction",
        "associated_object_id": "transaction_abc123",
        "type": "event"
      }
    JSON
    let(:new_body) { JSON.parse(<<~JSON) }
      {
        "id": "transfer_event_123",
        "created_at": "2020-02-20T23:59:59Z",
        "category": "transaction.created",
        "associated_object_type": "transaction",
        "associated_object_id": "transaction_abc123",
        "type": "event2"
      }
    JSON
  end

  it_behaves_like "a replicator that can backfill", "increase_event_v1" do
    let(:api_url) { "https://api.increase.com" }
    let(:page1_response) { <<~JSON }
      {
        "data": [
          {
            "id": "event_in71c4amph0vgo2qllky",
            "created_at": "2020-01-31T23:59:59Z",
            "associated_object_type": "fake",
            "associated_object_id": "fake_n8y8tnk2p9339ti393yi",
            "category": "fake",
            "type": "event"
          },
          {
            "id": "event_in72c4amph0vgo2qllky",
            "balance": 100,
            "created_at": "2020-01-31T23:59:59Z",
            "associated_object_type": "fake",
            "associated_object_id": "fake_n8y8tnk2p9339ti393yi",
            "category":  "fake",
            "type":  "event"
          }
        ],
        "response_metadata": {
          "next_cursor": "aW1pdCI6Mn0sInBvc2l0aW9uIjp7Im9mZnNldCI6NH19"
        }
      }
    JSON
    let(:page2_response) { <<~JSON }
      {
        "data": [
          {
            "id": "event_in73c4amph0vgo2qllky",
            "balance": 100,
            "created_at": "2020-01-31T23:59:59Z",
            "associated_object_type": "fake",
            "associated_object_id": "fake_n8y8tnk2p9339ti393yi",
            "category":  "fake",
            "type":  "event"
          },
          {
            "id": "event_in74c4amph0vgo2qllky",
            "balance": 100,
            "created_at": "2020-01-31T23:59:59Z",
            "associated_object_type": "fake",
            "associated_object_id": "fake_n8y8tnk2p9339ti393yi",
            "category":  "fake",
            "type":  "event"
          }
        ],
        "response_metadata": {
          "next_cursor": "lpYUWlPako5ZlEiLCJsaW1pdCI6Mn0sInBvc2l0aW9uIjp7Im9mZnNldCI6Nn19"
        }
      }
    JSON
    let(:page3_response) { <<~JSON }
      {
        "data": [],
        "response_metadata": {
          "next_cursor": null
        }
      }
    JSON
    let(:expected_items_count) { 4 }
    def stub_service_requests
      return [
        stub_request(:get, "https://api.increase.com/events").
            with(headers: {"Authorization" => "Bearer bfkey"}).
            to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://api.increase.com/events?cursor=aW1pdCI6Mn0sInBvc2l0aW9uIjp7Im9mZnNldCI6NH19").
            to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://api.increase.com/events?cursor=lpYUWlPako5ZlEiLCJsaW1pdCI6Mn0sInBvc2l0aW9uIjp7Im9mZnNldCI6Nn19").
            to_return(status: 200, body: page3_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_empty_requests
      return [
        stub_request(:get, "https://api.increase.com/events").
            to_return(status: 200, body: page3_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.increase.com/events").
          to_return(status: 400, body: "gah")
    end
  end

  # describe "webhook validation" do
  #   let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "increase_event_v1") }
  #   let(:svc) { Webhookdb::Replicator.create(sint) }
  #
  #   it "returns a 401 as per spec if there is no Authorization header" do
  #     req = fake_request
  #     status, _headers, _body = svc.webhook_response(req).to_rack
  #     expect(status).to eq(401)
  #   end
  #
  #   it "returns a 401 for an invalid Authorization header" do
  #     sint.update(webhook_secret: "user:pass")
  #     req = fake_request(input: '{"data": "asdfghujkl"}')
  #     data = req.body
  #     computed_auth = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), "user:pass", '{"data": "foobar"}')
  #     req.add_header("HTTP_X_BANK_WEBHOOK_SIGNATURE", "sha256=" + computed_auth)
  #     status, _headers, body = svc.webhook_response(req).to_rack
  #     expect(status).to eq(401)
  #     expect(body).to include("invalid hmac")
  #   end
  #
  #   it "returns a 202 with a valid Authorization header" do
  #     sint.update(webhook_secret: "user:pass")
  #     req = fake_request(input: '{"data": "asdfghujkl"}')
  #     data = req.body
  #     computed_auth = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), "user:pass", data)
  #     req.add_header("HTTP_X_BANK_WEBHOOK_SIGNATURE", "sha256=" + computed_auth)
  #     status, _headers, _body = svc.webhook_response(req).to_rack
  #     expect(status).to eq(202)
  #   end
  # end
  #
  # describe "state machine calculation" do
  #   let(:sint) do
  #     # Set api url to empty string so that backfill flow works correctly for testing purposes
  #     Webhookdb::Fixtures.service_integration.create(service_name: "increase_event_v1", api_url: "")
  #   end
  #   let(:svc) { Webhookdb::Replicator.create(sint) }
  #
  #   describe "process_state_change" do
  #     it "uses a default api url if value is blank" do
  #       sint.replicator.process_state_change("api_url", "")
  #       expect(sint.api_url).to eq("https://api.increase.com")
  #     end
  #   end
  #
  #   describe "calculate_webhook_state_machine" do
  #     it "tells the user to check out the docs" do
  #       sm = sint.replicator.calculate_webhook_state_machine
  #       expect(sm).to have_attributes(
  #         needs_input: false,
  #         prompt: "",
  #         prompt_is_secret: false,
  #         post_to_url: "",
  #         complete: true,
  #         output: match("Great! WebhookDB is now listening for Increase Account webhooks."),
  #       )
  #     end
  #   end
  #
  #   describe "calculate_backfill_state_machine" do
  #     it "tells the user to check out the docs" do
  #       sint.backfill_key = "bfkey"
  #       sint.api_url = "https://api.increase.com"
  #       res = stub_service_request
  #       sm = sint.replicator.calculate_backfill_state_machine
  #       expect(res).to have_been_made
  #       expect(sm).to have_attributes(
  #         needs_input: false,
  #         prompt: "",
  #         prompt_is_secret: false,
  #         post_to_url: "",
  #         complete: true,
  #         output: match("Great! We are going to start backfilling your Increase Accounts."),
  #       )
  #     end
  #   end
  # end
end
