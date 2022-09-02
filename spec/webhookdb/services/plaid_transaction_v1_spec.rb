# frozen_string_literal: true

require "support/shared_examples_for_services"

RSpec.describe Webhookdb::Services::PlaidTransactionV1, :db do
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }
  let(:dependency) { fac.with_encryption_secret.create(service_name: "plaid_item_v1") }
  let(:dep_svc) { dependency.service_instance }
  let(:sint) { fac.depending_on(dependency).create(service_name: "plaid_transaction_v1").refresh }
  let(:svc) { sint.service_instance }
  let(:item_id) do
    @item_id ||= 0
    @item_id += 1
    "itemid-#{@item_id}"
  end

  def insert_item_row(plaid_id: item_id, **more)
    dep_svc.admin_dataset do |ds|
      ds.insert(
        data: "{}",
        plaid_id:,
        encrypted_access_token: Webhookdb::Crypto.encrypt_value(
          Webhookdb::Crypto::Boxed.from_b64(dependency.data_encryption_secret),
          Webhookdb::Crypto::Boxed.from_raw("atok"),
        ).base64,
        **more,
      )
      return ds.order(:pk).last
    end
  end

  def insert_transaction_row(plaid_id, **more)
    svc.admin_dataset { |ds| ds.insert(data: "{}", plaid_id:, item_id:, **more) }
  end

  def create_body(plaid_id: item_id, code: "BLEH", **more)
    b = {
      webhook_type: "TRANSACTIONS",
      webhook_code: code,
      item_id: plaid_id,
      error: nil,
    }
    b.merge!(**more)
    b.stringify_keys!
    return b
  end

  it_behaves_like "a service implementation dependent on another", "plaid_transaction_v1", "plaid_item_v1" do
    let(:no_dependencies_message) { "This integration requires Plaid Items to sync" }
  end

  describe "upserting a webhook" do
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
    let(:end_date) { Time.now.tomorrow.strftime("%Y-%m-%d") }
    let(:page1_response) do
      tkey = ["added", "modified"].sample
      <<~R
        {
          "accounts": [],
          "#{tkey}": [
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
          "next_cursor": "cursor1",
          "has_more": true,
          "request_id": "45QSn"
        }
      R
    end
    let(:page2_response) do
      tkey = ["added", "modified"].sample
      <<~R
        {
          "accounts": [],
          "#{tkey}": [
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
          "next_cursor": "cursor2",
          "has_more": true,
          "request_id": "45QSn"
        }
      R
    end
    let(:page3_response) do
      <<~R
        {
          "accounts": [],
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
          "next_cursor": "cursor3",
          "has_more": false,
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

    def stub_service_request(body, cursor:)
      return stub_request(:post, "https://sandbox.plaid.com/transactions/sync").
          with(body: hash_including(
            "access_token" => "atok",
            "client_id" => "bfkey",
            "secret" => "bfsek",
            "count" => 1,
            "cursor" => cursor,
          )).to_return(status: 200, body:, headers: {"Content-Type" => "application/json"})
    end

    def stub_service_request_error
      return stub_request(:post, "https://sandbox.plaid.com/transactions/sync").
          with(body: hash_including({})).to_return(status: 503, body: "uhh")
    end

    describe "when there is no Plaid Item for the item id" do
      it "errors" do
        expect do
          svc.upsert_webhook_body(create_body)
        end.to raise_error(Webhookdb::InvalidPrecondition, /could not find Plaid item/)
      end

      it "noops in regression mode", :regression_mode do
        expect { svc.upsert_webhook_body(create_body) }.to_not raise_error
      end
    end

    it "marks transactions removed for that webhook" do
      insert_item_row
      t = 2.days.ago
      insert_transaction_row("x1", row_updated_at: t)
      insert_transaction_row("x2", row_updated_at: t)
      insert_transaction_row("x3", row_updated_at: t)

      resp_body = <<~R
        {
          "accounts": [],
          "removed": [
            {"transaction_id": "x1"},
            {"transaction_id": "x3"}
          ],
          "next_cursor": "cursor3",
          "has_more": false
        }
      R
      resp = stub_service_request(resp_body, cursor: nil)

      svc.upsert_webhook_body(create_body)

      expect(resp).to have_been_made
      rows = svc.readonly_dataset(&:all)
      expect(rows).to contain_exactly(
        include(plaid_id: "x1", removed_at: match_time(:now), row_updated_at: match_time(:now)),
        include(plaid_id: "x2", removed_at: nil, row_updated_at: match_time(t)),
        include(plaid_id: "x3", removed_at: match_time(:now), row_updated_at: match_time(:now)),
      )
    end

    it "inserts records for pages of results" do
      responses = [
        stub_service_request(page1_response, cursor: nil),
        stub_service_request(page2_response, cursor: "cursor1"),
        stub_service_request(page3_response, cursor: "cursor2"),
      ]
      insert_item_row
      transaction_svc.upsert_webhook_body(create_body)
      expect(responses).to all(have_been_made)
      rows = transaction_svc.readonly_dataset(&:all)
      expect(rows).to have_length(2)
      expect(rows).to contain_exactly(
        include(item_id:, plaid_id: "abc123"),
        include(item_id:, plaid_id: "def456"),
      )
    end

    it "upserts on the transaction id" do
      responses = [
        stub_service_request(page1_response, cursor: nil),
        stub_service_request(page2_response, cursor: "cursor1"),
        stub_service_request(page3_response, cursor: "cursor2"),
      ]
      insert_item_row
      transaction_svc.upsert_webhook_body(create_body)
      expect(responses[0]).to have_been_made
      expect(responses[1]).to have_been_made
      expect(responses[2]).to have_been_made
      expect(responses).to all(have_been_made)
      WebMock.reset!
      responses = [
        stub_service_request(page1_response, cursor: "cursor3"),
        stub_service_request(page2_response, cursor: "cursor1"),
        stub_service_request(page3_response, cursor: "cursor2"),
      ]
      transaction_svc.upsert_webhook_body(create_body)
      expect(responses).to all(have_been_made)

      rows = transaction_svc.readonly_dataset(&:all)
      expect(rows).to have_length(2)
      expect(rows).to contain_exactly(
        include(item_id:, plaid_id: "abc123"),
        include(item_id:, plaid_id: "def456"),
      )
    end

    it "errors if backfill credentials are not present" do
      item_sint.update(backfill_key: "")
      insert_item_row
      expect do
        transaction_svc.upsert_webhook_body(create_body)
      end.to raise_error(Webhookdb::Services::CredentialsMissing)
    end

    it "errors if fetching page errors" do
      expect(Webhookdb::Backfiller).to receive(:do_retry_wait).twice # Mock out the sleep
      response = stub_service_request_error
      insert_item_row
      expect do
        transaction_svc.upsert_webhook_body(create_body)
      end.to raise_error(Webhookdb::Http::Error)
      expect(response).to have_been_made.times(3)
    end

    it "returns if a storable error occurs" do
      expect(Webhookdb::Backfiller).to_not receive(:do_retry_wait)
      plaid_body = <<~J
        {
          "error_type": "ITEM_ERROR",
          "error_code": "PRODUCT_NOT_READY",
          "error_message": "the requested product is not yet ready. please provide a webhook or try the request again later",
          "display_message": null,
          "request_id": "HNTDNrA8F1shFEW"
        }
      J
      response = stub_request(:post, "https://sandbox.plaid.com/transactions/sync").
        to_return(status: 400, body: plaid_body, headers: {"Content-Type" => "application/json"})
      insert_item_row
      transaction_svc.upsert_webhook_body(create_body)
      expect(response).to have_been_made
    end

    it "uses the backfill token as the cursor" do
      insert_transaction_row("abc")
      insert_transaction_row("xyz")
      insert_item_row(transaction_sync_next_cursor: "cursor0")
      responses = [
        stub_service_request(page1_response, cursor: "cursor0"),
        stub_service_request(page2_response, cursor: "cursor1"),
        stub_service_request(page3_response, cursor: "cursor2"),
      ]
      transaction_svc.upsert_webhook_body(create_body)
      expect(responses).to all(have_been_made)
      expect(transaction_svc.readonly_dataset(&:all)).to have_length(4) # 2 backfilled, 2 existed
      dep_svc.admin_dataset do |ds|
        expect(ds[plaid_id: item_id]).to include(transaction_sync_next_cursor: "cursor3")
      end
    end

    it "commits changes and raises a retry on 429" do
      rate_limit_body = <<~J
        {
          "error_type": "RATE_LIMIT_EXCEEDED",
          "error_code": "TRANSACTIONS_LIMIT",
          "error_message": "rate limit exceeded for attempts to access this item. please try again later",
          "display_message": null,
          "request_id": "HNTDNrA8F1shFEW"
        }
      J
      req = stub_request(:post, "https://sandbox.plaid.com/transactions/sync").
        to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}).
        to_return(status: 429, body: rate_limit_body, headers: {"Content-Type" => "application/json"})
      insert_item_row
      expect do
        transaction_svc.upsert_webhook_body(create_body)
      end.to raise_error(Webhookdb::Async::Job::Retry)
      expect(req).to have_been_made.twice

      rows = transaction_svc.readonly_dataset(&:all)
      expect(rows).to contain_exactly(
        include(item_id:, plaid_id: "abc123"),
      )
    end

    it "raises a special error for timeouts" do
      req = stub_request(:post, "https://sandbox.plaid.com/transactions/sync").and_raise(Net::ReadTimeout)
      insert_item_row
      expect do
        transaction_svc.upsert_webhook_body(create_body)
      end.to raise_error(described_class::PlaidAtItAgain)
      expect(req).to have_been_made
    end

    describe "created and updated timestamps" do
      it "are set on insert" do
        responses = [
          stub_service_request(page1_response, cursor: nil),
          stub_service_request(page2_response, cursor: "cursor1"),
          stub_service_request(page3_response, cursor: "cursor2"),
        ]
        insert_item_row
        transaction_svc.upsert_webhook_body(create_body)
        expect(responses).to all(have_been_made)
        rows = transaction_svc.readonly_dataset(&:all)
        expect(rows).to have_length(2)
        expect(rows.first).to include(row_created_at: match_time(:now), row_updated_at: match_time(:now))
      end

      it "does not modify created at on update" do
        t = 2.day.ago
        insert_transaction_row("abc123", row_created_at: t, row_updated_at: t)
        insert_transaction_row("def456", row_created_at: t, row_updated_at: t)
        responses = [
          stub_service_request(page1_response, cursor: nil),
          stub_service_request(page2_response, cursor: "cursor1"),
          stub_service_request(page3_response, cursor: "cursor2"),
        ]
        insert_item_row
        transaction_svc.upsert_webhook_body(create_body)
        rows = transaction_svc.readonly_dataset(&:all)
        expect(responses).to all(have_been_made)
        expect(rows).to have_length(2)
        expect(rows.first).to include(row_created_at: match_time(t), row_updated_at: match_time(:now))
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
