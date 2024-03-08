# frozen_string_literal: true

require_relative "increase_shared_examples"

RSpec.describe Webhookdb::Replicator::IncreaseAccountNumberV1, :db do
  it_behaves_like "an Increase replicator dependent on events and increase_app_v1" do
    let(:list_path) { "/account_numbers" }
    let(:denormalized_key) { :account_number }
    let(:doc_resource_json) { <<~JSON }
      {
        "account_id": "account_in71c4amph0vgo2qllky",
        "account_number": "987654321",
        "id": "account_number_v18nkfqm6afpsrvy82b2",
        "created_at": "2020-01-31T23:59:59Z",
        "name": "ACH",
        "routing_number": "101050001",
        "status": "active",
        "inbound_ach": {
          "debit_status": "blocked"
        },
        "inbound_checks": {
          "status": "check_transfers_only"
        },
        "replacement": {
          "replaced_account_number_id": null,
          "replaced_by_account_number_id": null
        },
        "idempotency_key": null,
        "type": "account_number"
      }
    JSON
  end
end
