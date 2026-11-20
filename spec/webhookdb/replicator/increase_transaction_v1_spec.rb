# frozen_string_literal: true

require_relative "increase_shared_examples"

RSpec.describe Webhookdb::Replicator::IncreaseTransactionV1, :db do
  it_behaves_like "an Increase replicator dependent on events and increase_app_v1" do
    let(:list_path) { "/transactions" }
    let(:denormalized_key) { :route_id }
    let(:doc_resource_json) { <<~JSON }
      {
        "account_id": "account_in71c4amph0vgo2qllky",
        "amount": 100,
        "currency": "USD",
        "created_at": "2020-01-31T23:59:59Z",
        "description": "INVOICE 2468",
        "id": "transaction_uyrp7fld2ium70oa7oi",
        "route_id": "account_number_v18nkfqm6afpsrvy82b2",
        "route_type": "account_number",
        "source": {
          "category": "inbound_ach_transfer",
          "inbound_ach_transfer": {
            "amount": 100,
            "originator_company_name": "BIG BANK",
            "originator_company_descriptive_date": null,
            "originator_company_discretionary_data": null,
            "originator_company_entry_description": "RESERVE",
            "originator_company_id": "0987654321",
            "receiver_id_number": "12345678900",
            "receiver_name": "IAN CREASE",
            "trace_number": "021000038461022",
            "transfer_id": "inbound_ach_transfer_tdrwqr3fq9gnnq49odev",
            "addenda": null
          }
        },
        "type": "transaction"
      }
    JSON
  end
end
