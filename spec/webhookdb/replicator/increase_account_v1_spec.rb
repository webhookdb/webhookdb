# frozen_string_literal: true

require_relative "increase_shared_examples"

RSpec.describe Webhookdb::Replicator::IncreaseAccountV1, :db do
  it_behaves_like "an Increase replicator dependent on events and increase_app_v1" do
    let(:list_path) { "/accounts" }
    let(:denormalized_key) { :status }
    let(:doc_resource_json) { <<~JSON }
      {
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
  end
end
