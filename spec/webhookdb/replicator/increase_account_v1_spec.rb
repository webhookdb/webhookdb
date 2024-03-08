# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::IncreaseAccountV1, :db do
  it_behaves_like "a replicator", "increase_account_v1" do
    let(:body) { JSON.parse(<<~JSON) }
      {
        "updated_at": "2020-01-31T23:59:59Z",
        "id": "account_in71c4amph0vgo2qllky",
        "balance": 100,
        "created_at": "2020-01-31T23:59:59Z",
        "currency": "USD",
        "entity_id": "entity_n8y8tnk2p9339ti393yi",
        "interest_accrued": "0.01",
        "interest_accrued_at": "2020-01-31",
        "name": "My first account!",
        "status": "open",
        "type": "account"
      }
    JSON
  end

  it_behaves_like "a replicator that prevents overwriting new data with old", "increase_account_v1" do
    let(:old_body) { JSON.parse(<<~JSON) }
      {
        "updated_at": "2020-01-31T23:59:59Z",
        "id": "account_in71c4amph0vgo2qllky",
        "balance": 100,
        "created_at": "2020-01-31T23:59:59Z",
        "currency": "USD",
        "entity_id": "entity_n8y8tnk2p9339ti393yi",
        "interest_accrued": "0.01",
        "interest_accrued_at": "2020-01-31",
        "name": "My first account!",
        "status": "open",
        "type": "account"
      }
    JSON
    let(:new_body) { JSON.parse(<<~JSON) }
      {
        "updated_at": "2020-02-20T23:59:59Z",
        "id": "account_in71c4amph0vgo2qllky",
        "balance": 100,
        "created_at": "2020-01-31T23:59:59Z",
        "currency": "USD",
        "entity_id": "entity_n8y8tnk2p9339ti393yi",
        "interest_accrued": "0.01",
        "interest_accrued_at": "2020-01-31",
        "name": "My first account!",
        "status": "open",
        "type": "account"
      }
    JSON
  end

  it_behaves_like "a replicator that uses enrichments", "increase_account_v1", stores_enrichment_column: false do
    before(:each) do
      create_all_dependencies(sint).first.update(backfill_key: "access-tok", api_url: "https://api.increase.com")
    end

    let(:body) { JSON.parse(<<~JSON) }
      {
        "associated_object_id": "account_in71c4amph0vgo2qllky",
        "associated_object_type": "account",
        "category": "account.created",
        "created_at": "2022-01-31T23:59:59Z",
        "id": "event_001dzz0r20rzr4zrhrr1364hy80",
        "type": "event"
      }
    JSON
    let(:response_body) { <<~JSON }
      {
        "balance": 5,
        "bank": "first_internet_bank",
        "created_at": "2020-01-31T23:59:59Z",
        "currency": "USD",
        "entity_id": "entity_n8y8tnk2p9339ti393yi",
        "informational_entity_id": null,
        "id": "account_in71c4amph0vgo2qllky",
        "interest_accrued": "0.01",
        "interest_accrued_at": "2020-01-31",
        "interest_rate": "0.055",
        "name": "My first account!",
        "status": "open",
        "replacement": {
          "replaced_account_id": null,
          "replaced_by_account_id": null
        },
        "type": "account",
        "idempotency_key": null
      }
    JSON

    def stub_service_request
      return stub_request(:get, "https://api.increase.com/accounts/account_in71c4amph0vgo2qllky").
          to_return(
            status: 200,
            headers: {"Content-Type" => "application/json", "Authorization" => "Bearer access-tok"},
            body: response_body,
          )
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.increase.com/accounts/account_in71c4amph0vgo2qllky").
          to_return(status: 503, body: "nope")
    end

    def assert_is_enriched(row)
      expect(row).to include(
        balance: 5,
        created_at: match_time("2020-01-31T23:59:59Z"),
        updated_at: match_time("2022-01-31T23:59:59Z"),
      )
    end
  end

  it_behaves_like "a replicator that can backfill", "increase_account_v1" do
    def create_all_dependencies(sint)
      r = super
      sint.depends_on&.update(backfill_key: "access-tok", api_url: "https://api.increase.com")
      return r
    end

    let(:page1_response) { <<~JSON }
      {
        "data": [
          {
            "id": "account_in71c4amph0vgo2qllky",
            "balance": 100,
            "currency": "USD",
            "entity_id": "entity_n8y8tnk2p9339ti393yi",
            "interest_accrued": "0.01",
            "interest_accrued_at": "2020-01-31",
            "name": "My first account!",
            "type": "account",
            "created_at": "2021-08-17T19:05:15Z",
            "network": "ach",
            "path": "/account/account_in71c4amph0vgo2qllky",
            "status": "returned",
            "transaction_id": "transaction_qrejyflufbtax3zaejbp"
          },
          {
            "id": "account_in72c4amph0vgo2qllky",
            "balance": 100,
            "currency": "USD",
            "entity_id": "entity_n8y8tnk2p9339ti393yi",
            "interest_accrued": "0.01",
            "interest_accrued_at": "2020-01-31",
            "name": "My first account!",
            "type": "account",
            "created_at": "2021-08-17T07:49:07Z",
            "network": "ach",
            "path": "/account/account_in72c4amph0vgo2qllky",
            "status": "submitted",
            "transaction_id": "transaction_4hfmdlbizqalyak0vhvy"
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
            "id": "account_in73c4amph0vgo2qllky",
            "balance": 100,
            "currency": "USD",
            "entity_id": "entity_n8y8tnk2p9339ti393yi",
            "interest_accrued": "0.01",
            "interest_accrued_at": "2020-01-31",
            "name": "My first account!",
            "type": "account",
            "created_at": "2021-08-16T06:05:17Z",
            "network": "ach",
            "path": "/account/account_in73c4amph0vgo2qllky",
            "status": "submitted",
            "transaction_id": "transaction_dp1nktbjmocrl4doinbs"
          },
          {
            "id": "account_in74c4amph0vgo2qllky",
            "balance": 100,
            "currency": "USD",
            "entity_id": "entity_n8y8tnk2p9339ti393yi",
            "interest_accrued": "0.01",
            "interest_accrued_at": "2020-01-31",
            "name": "My first account!",
            "type": "account",
            "created_at": "2021-08-16T05:05:38Z",
            "network": "ach",
            "path": "/account/account_in74c4amph0vgo2qllky",
            "status": "returned",
            "transaction_id": "transaction_ehcs1vylp3koisigf7xw"
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
        stub_request(:get, "https://api.increase.com/accounts").
            with(headers: {"Authorization" => "Bearer access-tok"}).
            to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://api.increase.com/accounts?cursor=aW1pdCI6Mn0sInBvc2l0aW9uIjp7Im9mZnNldCI6NH19").
            to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://api.increase.com/accounts?cursor=lpYUWlPako5ZlEiLCJsaW1pdCI6Mn0sInBvc2l0aW9uIjp7Im9mZnNldCI6Nn19").
            to_return(status: 200, body: page3_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_empty_requests
      return [
        stub_request(:get, "https://api.increase.com/accounts").
            to_return(status: 200, body: page3_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.increase.com/accounts").
          to_return(status: 400, body: "gah")
    end
  end
end
