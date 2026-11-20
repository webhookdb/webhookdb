# frozen_string_literal: true

require_relative "increase_shared_examples"

RSpec.describe Webhookdb::Replicator::IncreaseCheckTransferV1, :db do
  it_behaves_like "an Increase replicator dependent on events and increase_app_v1" do
    let(:list_path) { "/check_transfers" }
    let(:denormalized_key) { :routing_number }
    let(:doc_resource_json) { <<~JSON }
      {
        "account_id": "account_in71c4amph0vgo2qllky",
        "source_account_number_id": "account_number_v18nkfqm6afpsrvy82b2",
        "account_number": "987654321",
        "routing_number": "101050001",
        "check_number": "123",
        "fulfillment_method": "physical_check",
        "physical_check": {
          "memo": "Invoice 29582",
          "note": null,
          "recipient_name": "Ian Crease",
          "mailing_address": {
            "name": "Ian Crease",
            "line1": "33 Liberty Street",
            "line2": null,
            "city": "New York",
            "state": "NY",
            "postal_code": "10045"
          },
          "return_address": {
            "name": "Ian Crease",
            "line1": "33 Liberty Street",
            "line2": null,
            "city": "New York",
            "state": "NY",
            "postal_code": "10045"
          }
        },
        "amount": 1000,
        "created_at": "2020-01-31T23:59:59Z",
        "currency": "USD",
        "approval": null,
        "cancellation": null,
        "id": "check_transfer_30b43acfu9vw8fyc4f5",
        "mailing": {
          "mailed_at": "2020-01-31T23:59:59Z",
          "image_id": null
        },
        "pending_transaction_id": "pending_transaction_k1sfetcau2qbvjbzgju4",
        "status": "mailed",
        "submission": {
          "submitted_at": "2020-01-31T23:59:59Z"
        },
        "stop_payment_request": null,
        "deposit": {
          "deposited_at": "2020-01-31T23:59:59Z",
          "transaction_id": "transaction_uyrp7fld2ium70oa7oi",
          "front_image_file_id": "file_makxrc67oh9l6sg7w9yc",
          "back_image_file_id": "file_makxrc67oh9l6sg7w9yc",
          "bank_of_first_deposit_routing_number": null,
          "transfer_id": "check_transfer_30b43acfu9vw8fyc4f5",
          "type": "check_transfer_deposit"
        },
        "idempotency_key": null,
        "type": "check_transfer"
      }
    JSON
  end
end
