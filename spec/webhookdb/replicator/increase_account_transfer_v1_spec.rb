# frozen_string_literal: true

require_relative "increase_shared_examples"

RSpec.describe Webhookdb::Replicator::IncreaseAccountTransferV1, :db do
  it_behaves_like "an Increase replicator dependent on events and increase_app_v1" do
    let(:list_path) { "/account_transfers" }
    let(:denormalized_key) { :destination_account_id }
    let(:doc_resource_json) { <<~JSON }
      {
        "id": "account_transfer_7k9qe1ysdgqztnt63l7n",
        "amount": 100,
        "account_id": "account_in71c4amph0vgo2qllky",
        "currency": "USD",
        "destination_account_id": "account_uf16sut2ct5bevmq3eh",
        "destination_transaction_id": "transaction_j3itv8dtk5o8pw3p1xj4",
        "created_at": "2020-01-31T23:59:59Z",
        "description": "Move money into savings",
        "network": "account",
        "status": "complete",
        "transaction_id": "transaction_uyrp7fld2ium70oa7oi",
        "pending_transaction_id": null,
        "approval": {
          "approved_at": "2020-01-31T23:59:59Z",
          "approved_by": null
        },
        "cancellation": null,
        "idempotency_key": null,
        "type": "account_transfer"
      }
    JSON
  end
end
