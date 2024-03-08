# frozen_string_literal: true

require_relative "increase_shared_examples"

RSpec.describe Webhookdb::Replicator::IncreaseWireTransferV1, :db do
  it_behaves_like "an Increase replicator dependent on events and increase_app_v1" do
    let(:list_path) { "/wire_transfers" }
    let(:denormalized_key) { :account_id }
    let(:doc_resource_json) { <<~JSON }
      {
        "id": "wire_transfer_5akynk7dqsq25qwk9q2u",
        "message_to_recipient": "Message to recipient",
        "amount": 100,
        "currency": "USD",
        "account_number": "987654321",
        "beneficiary_name": null,
        "beneficiary_address_line1": null,
        "beneficiary_address_line2": null,
        "beneficiary_address_line3": null,
        "beneficiary_financial_institution_identifier_type": null,
        "beneficiary_financial_institution_identifier": null,
        "beneficiary_financial_institution_name": null,
        "beneficiary_financial_institution_address_line1": null,
        "beneficiary_financial_institution_address_line2": null,
        "beneficiary_financial_institution_address_line3": null,
        "originator_name": null,
        "originator_address_line1": null,
        "originator_address_line2": null,
        "originator_address_line3": null,
        "account_id": "account_in71c4amph0vgo2qllky",
        "external_account_id": "external_account_ukk55lr923a3ac0pp7iv",
        "routing_number": "101050001",
        "approval": {
          "approved_at": "2020-01-31T23:59:59Z",
          "approved_by": null
        },
        "cancellation": null,
        "reversal": null,
        "created_at": "2020-01-31T23:59:59Z",
        "network": "wire",
        "status": "complete",
        "submission": null,
        "transaction_id": "transaction_uyrp7fld2ium70oa7oi",
        "pending_transaction_id": null,
        "idempotency_key": null,
        "type": "wire_transfer"
      }
    JSON
  end
end
