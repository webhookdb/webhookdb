# frozen_string_literal: true

require "support/shared_examples_for_services"

RSpec.describe Webhookdb::Services::PlaidTransactionV1, :db do
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }
  let(:dependency) { fac.with_encryption_secret.create(service_name: "plaid_item_v1") }
  let(:dep_svc) { dependency.service_instance }
  let(:sint) { fac.depending_on(dependency).create(service_name: "plaid_transaction_v1").refresh }
  let(:svc) { sint.service_instance }
  let(:item_id) { SecureRandom.hex(5) }

  def insert_item_row
    dep_svc.admin_dataset do |ds|
      ds.insert(
        data: "{}",
        plaid_id: item_id,
        encrypted_access_token: Webhookdb::Crypto.encrypt_value(
          Webhookdb::Crypto::Boxed.from_b64(dependency.data_encryption_secret),
          Webhookdb::Crypto::Boxed.from_raw("atok"),
        ).base64,
      )
      return ds.order(:pk).last
    end
  end

  def insert_transaction_row(plaid_id, **more)
    svc.admin_dataset { |ds| ds.insert(data: "{}", plaid_id:, item_id:, **more) }
  end

  describe "upsert_webhook" do
    before(:each) do
      org.prepare_database_connections
    end

    after(:each) do
      org.remove_related_database
    end

    def create_body(item_id, code, **more)
      b = {
        webhook_type: "TRANSACTIONS",
        webhook_code: code,
        item_id:,
        error: nil,
      }
      b.merge!(**more)
      b.stringify_keys!
      return b
    end

    it "errors if there is no Plaid Item for the item id" do
      dep_svc.create_table
      svc.create_table
      expect do
        svc.upsert_webhook(body: create_body(item_id, "FOO"))
      end.to raise_error(Webhookdb::InvalidPrecondition, /could not find Plaid item/)
    end

    it "marks transactions removed for that webhook" do
      dep_svc.create_table
      svc.create_table
      insert_item_row
      insert_transaction_row("x1")
      insert_transaction_row("x2")
      insert_transaction_row("x3")
      svc.upsert_webhook(body: create_body(item_id, "TRANSACTIONS_REMOVED", removed_transactions: ["x1", "x3"]))
      rows = svc.readonly_dataset(&:all)
      expect(rows).to contain_exactly(
        include(plaid_id: "x1", removed_at: match_time(Time.now).within(5)),
        include(plaid_id: "x2", removed_at: nil),
        include(plaid_id: "x3", removed_at: match_time(Time.now).within(5)),
      )
    end

    it "backfills all transactions for a historical update" do
      dep_svc.create_table
      svc.create_table
      insert_item_row
      expect(svc).to receive(:handle_historical_update).
        with(be_a(Webhookdb::Services::PlaidItemV1), include(plaid_id: item_id))
      svc.upsert_webhook(body: create_body(item_id, "HISTORICAL_UPDATE"))
    end

    it "backfills incrementally for all other update types" do
      dep_svc.create_table
      svc.create_table
      insert_item_row
      expect(svc).to receive(:handle_incremental_update).
        with(be_a(Webhookdb::Services::PlaidItemV1), include(plaid_id: item_id))
      svc.upsert_webhook(body: create_body(item_id, "DEFAULT_UPDATE"))
    end
  end

  it_behaves_like "a service implementation dependent on another", "plaid_transaction_v1", "plaid_item_v1" do
    let(:no_dependencies_message) { "This integration requires Plaid Items to sync" }
  end
  describe "backfill process" do
    let(:item_sint) do
      dependency.update(
        backfill_key: "bfkey",
        backfill_secret: "bfsek",
        api_url: "https://sandbox.plaid.com",
      )
    end
    let(:item_svc) { item_sint.service_instance }
    let(:transaction_sint) { sint }
    let(:transaction_svc) { transaction_sint.service_instance }
    let(:item_row) { insert_item_row }
    let(:end_date) { Time.now.tomorrow.strftime("%Y-%m-%d") }
    let(:page1_response) do
      <<~R
                {
          "accounts": [],
          "transactions": [
            {
              "account_id": "BxBXxLj1m4HMXBm9WZZmCWVbPjX16EHwv99vp",
              "amount": 2307.21,
              "iso_currency_code": "USD",
              "unofficial_currency_code": null,
              "category": [
                "Shops",
                "Computers and Electronics"
              ],
              "category_id": "19013000",
              "check_number": null,
              "date": "2017-01-29",
              "datetime": "2017-01-27T11:00:00Z",
              "authorized_date": "2017-01-27",
              "authorized_datetime": "2017-01-27T10:34:50Z",
              "location": {
                "address": "300 Post St",
                "city": "San Francisco",
                "region": "CA",
                "postal_code": "94108",
                "country": "US",
                "lat": 40.740352,
                "lon": -74.001761,
                "store_number": "1235"
              },
              "name": "Apple Store",
              "merchant_name": "Apple",
              "payment_meta": {
                "by_order_of": null,
                "payee": null,
                "payer": null,
                "payment_method": null,
                "payment_processor": null,
                "ppd_id": null,
                "reason": null,
                "reference_number": null
              },
              "payment_channel": "in store",
              "pending": false,
              "pending_transaction_id": null,
              "account_owner": null,
              "transaction_id": "abc123",
              "transaction_code": null,
              "transaction_type": "place"
            }
          ],
          "item": {
            "available_products": [],
            "billed_products": [],
            "consent_expiration_time": null,
            "error": null,
            "institution_id": "ins_3",
            "item_id": "plaiditemid",
            "update_type": "background",
            "webhook": "https://www.genericwebhookurl.com/webhook"
          },
          "total_transactions": 2,
          "request_id": "45QSn"
        }
      R
    end
    let(:page2_response) do
      <<~R
                {
          "accounts": [],
          "transactions": [
            {
              "account_id": "BxBXxLj1m4HMXBm9WZZmCWVbPjX16EHwv99vp",
              "amount": 2307.21,
              "iso_currency_code": "USD",
              "unofficial_currency_code": null,
              "category": [
                "Shops",
                "Computers and Electronics"
              ],
              "category_id": "19013000",
              "check_number": null,
              "date": "2017-01-29",
              "datetime": "2017-01-27T11:00:00Z",
              "authorized_date": "2017-01-27",
              "authorized_datetime": "2017-01-27T10:34:50Z",
              "location": {
                "address": "300 Post St",
                "city": "San Francisco",
                "region": "CA",
                "postal_code": "94108",
                "country": "US",
                "lat": 40.740352,
                "lon": -74.001761,
                "store_number": "1235"
              },
              "name": "Apple Store",
              "merchant_name": "Apple",
              "payment_meta": {
                "by_order_of": null,
                "payee": null,
                "payer": null,
                "payment_method": null,
                "payment_processor": null,
                "ppd_id": null,
                "reason": null,
                "reference_number": null
              },
              "payment_channel": "in store",
              "pending": false,
              "pending_transaction_id": null,
              "account_owner": null,
              "transaction_id": "def456",
              "transaction_code": null,
              "transaction_type": "place"
            }
          ],
          "item": {
            "available_products": [],
            "billed_products": [],
            "consent_expiration_time": null,
            "error": null,
            "institution_id": "ins_3",
            "item_id": "plaiditemid",
            "update_type": "background",
            "webhook": "https://www.genericwebhookurl.com/webhook"
          },
          "total_transactions": 2,
          "request_id": "45QSn"
        }
      R
    end
    let(:page3_response) do
      <<~R
                {
          "accounts": [],
          "transactions": [],
          "item": {
            "available_products": [],
            "billed_products": [],
            "consent_expiration_time": null,
            "error": null,
            "institution_id": "ins_3",
            "item_id": "plaiditemid",
            "update_type": "background",
            "webhook": "https://www.genericwebhookurl.com/webhook"
          },
          "total_transactions": 2,
          "request_id": "45QSn"
        }
      R
    end

    before(:each) do
      Webhookdb::Plaid.page_size = 1
      org.prepare_database_connections
      transaction_svc.create_table
      item_svc.create_table
    end

    after(:each) do
      org.remove_related_database
    end

    def stub_service_request(start_date, offset, body)
      return stub_request(:post, "https://sandbox.plaid.com/transactions/get").
          with(body: hash_including(
            "access_token" => "atok",
            "client_id" => "bfkey",
            "secret" => "bfsek",
            "start_date" => start_date.strftime("%Y-%m-%d"),
            "end_date" => end_date,
            "options" => {"count" => 1, "offset" => offset},
          )).to_return(status: 200, body:, headers: {"Content-Type" => "application/json"})
    end

    def stub_service_request_error
      return stub_request(:post, "https://sandbox.plaid.com/transactions/get").
          with(body: hash_including({})).to_return(status: 503, body: "uhh")
    end

    it "inserts records for pages of results" do
      start = 1.year.ago
      responses = [
        stub_service_request(start, 0, page1_response),
        stub_service_request(start, 1, page2_response),
        stub_service_request(start, 2, page3_response),
      ]
      transaction_svc.backfill_plaid_item(item_svc, item_row, 1.year.ago)
      expect(responses).to all(have_been_made)
      rows = transaction_svc.readonly_dataset(&:all)
      expect(rows).to have_length(2)
      expect(rows).to contain_exactly(
        include(item_id:, plaid_id: "abc123"),
        include(item_id:, plaid_id: "def456"),
      )
    end

    it "upserts on the transaction id" do
      start = 1.year.ago
      responses = [
        stub_service_request(start, 0, page1_response),
        stub_service_request(start, 1, page2_response),
        stub_service_request(start, 2, page3_response),
      ]
      transaction_svc.backfill_plaid_item(item_svc, item_row, 1.year.ago)
      expect(responses).to all(have_been_made)
      WebMock.reset!
      responses = [
        stub_service_request(start, 0, page1_response),
        stub_service_request(start, 1, page2_response),
        stub_service_request(start, 2, page3_response),
      ]
      transaction_svc.backfill_plaid_item(item_svc, item_row, 1.year.ago)
      expect(responses).to all(have_been_made)

      rows = transaction_svc.readonly_dataset(&:all)
      expect(rows).to have_length(2)
      expect(rows).to contain_exactly(
        include(item_id:, plaid_id: "abc123"),
        include(item_id:, plaid_id: "def456"),
      )
    end

    it "errors if backfill credentials are not present" do
      item_sint.backfill_key = ""
      expect do
        transaction_svc.backfill_plaid_item(item_svc, item_row, 1.year.ago)
      end.to raise_error(Webhookdb::Services::CredentialsMissing)
    end

    it "errors if fetching page errors" do
      expect(Webhookdb::Backfiller).to receive(:do_retry_wait).twice # Mock out the sleep
      response = stub_service_request_error
      expect do
        transaction_svc.backfill_plaid_item(item_svc, item_row, Time.now)
      end.to raise_error(Webhookdb::Http::Error)
      expect(response).to have_been_made.times(3)
    end

    describe "historical backfill" do
      it "always uses 2 years ago as its start date" do
        start = 2.years.ago
        insert_transaction_row("abc", datetime: 30.days.ago)
        responses = [
          stub_service_request(start, 0, page1_response),
          stub_service_request(start, 1, page2_response),
          stub_service_request(start, 2, page3_response),
        ]
        transaction_svc.handle_historical_update(item_svc, item_row)
        expect(responses).to all(have_been_made)
        expect(transaction_svc.readonly_dataset(&:all)).to have_length(3) # 2 backfilled, 1 existed
      end
    end

    describe "incremental backfill" do
      it "defaults to 2 years ago as its start date" do
        start = 2.years.ago
        responses = [
          stub_service_request(start, 0, page1_response),
          stub_service_request(start, 1, page2_response),
          stub_service_request(start, 2, page3_response),
        ]
        transaction_svc.handle_incremental_update(item_svc, item_row)
        expect(responses).to all(have_been_made)
        expect(transaction_svc.readonly_dataset(&:all)).to have_length(2)
      end

      it "will use the most recent transaction datetime as its start date" do
        start = Time.parse("2022-02-20T12:00:00Z")
        insert_transaction_row("abc", datetime: start)
        insert_transaction_row("xyz", datetime: start - 60.days)
        responses = [
          stub_service_request(start, 0, page1_response),
          stub_service_request(start, 1, page2_response),
          stub_service_request(start, 2, page3_response),
        ]
        transaction_svc.handle_incremental_update(item_svc, item_row)
        expect(responses).to all(have_been_made)
        expect(transaction_svc.readonly_dataset(&:all)).to have_length(4) # 2 backfilled, 2 existed
      end
    end
  end

  describe "state machine calculation" do
    describe "calculate_create_state_machine" do
      it "prompts for dependencies" do
        sint.update(depends_on: nil)
        dependency.destroy
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          output: match("This integration requires Plaid Items to sync"),
        )
      end

      it "succeeds and prints a success response if the dependency is set" do
        sint.webhook_secret = "whsec_abcasdf"
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          complete: true,
          output: match("If you have fully set up"),
        )
      end
    end

    describe "calculate_backfill_state_machine" do
      it "fails and explains why" do
        sm = sint.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          complete: true,
          output: match("We cannot backfill Plaid Transactions").and(match("you can query the Plaid")),
        )
      end
    end
  end
end
