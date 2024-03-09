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
        "category": "transaction.created2",
        "associated_object_type": "transaction",
        "associated_object_id": "transaction_abc123",
        "type": "event"
      }
    JSON
  end

  it_behaves_like "a replicator that can backfill", "increase_event_v1" do
    def create_all_dependencies(sint)
      r = super
      sint.depends_on&.update(backfill_key: "bfkey", api_url: "https://api.increase.com")
      return r
    end
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
end
