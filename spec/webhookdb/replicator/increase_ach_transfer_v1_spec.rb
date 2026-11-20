# frozen_string_literal: true

require_relative "increase_shared_examples"

RSpec.describe Webhookdb::Replicator::IncreaseACHTransferV1, :db do
  it_behaves_like "an Increase replicator dependent on events and increase_app_v1" do
    let(:list_path) { "/ach_transfers" }
    let(:denormalized_key) { :routing_number }
    let(:doc_resource_json) { <<~JSON }
      {
        "account_id": "account_in71c4amph0vgo2qllky",
        "account_number": "987654321",
        "addenda": null,
        "amount": 100,
        "currency": "USD",
        "approval": {
          "approved_at": "2020-01-31T23:59:59Z",
          "approved_by": null
        },
        "cancellation": null,
        "created_at": "2020-01-31T23:59:59Z",
        "destination_account_holder": "business",
        "external_account_id": "external_account_ukk55lr923a3ac0pp7iv",
        "id": "ach_transfer_uoxatyh3lt5evrsdvo7q",
        "network": "ach",
        "notifications_of_change": [],
        "return": null,
        "routing_number": "101050001",
        "statement_descriptor": "Statement descriptor",
        "status": "returned",
        "submission": {
          "trace_number": "058349238292834",
          "submitted_at": "2020-01-31T23:59:59Z",
          "expected_funds_settlement_at": "2020-02-03T13:30:00Z",
          "effective_date": "2020-01-31"
        },
        "acknowledgement": {
          "acknowledged_at": "2020-01-31T23:59:59Z"
        },
        "transaction_id": "transaction_uyrp7fld2ium70oa7oi",
        "pending_transaction_id": null,
        "company_descriptive_date": null,
        "company_discretionary_data": null,
        "company_entry_description": null,
        "company_name": "National Phonograph Company",
        "funding": "checking",
        "individual_id": null,
        "individual_name": "Ian Crease",
        "effective_date": null,
        "standard_entry_class_code": "corporate_credit_or_debit",
        "idempotency_key": null,
        "type": "ach_transfer"
      }
    JSON
  end
end
