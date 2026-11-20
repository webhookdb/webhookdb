# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::StripeChargeV1, :db do
  it_behaves_like "a replicator" do
    let(:body) do
      JSON.parse(<<~J)
        {
          "id": "evt_1CiPtv2eZvKYlo2CcUZsDcO6",
          "object": "event",
          "api_version": "2018-05-21",
          "created": 1530291411,
          "data": {
            "object": {
              "id": "ch_1IkvozFFYxHXGyKxDwTuyLZq",
              "object": "charge",
              "amount": 888,
              "amount_captured": 888,
              "amount_refunded": 0,
              "application": null,
              "application_fee": null,
              "application_fee_amount": null,
              "balance_transaction": "txn_1IkvozFFYxHXGyKxgxXkVSPw",
              "billing_details": {
                "address": {
                  "city": null,
                  "country": null,
                  "line1": null,
                  "line2": null,
                  "postal_code": null,
                  "state": null
                },
                "email": null,
                "name": null,
                "phone": null
              },
              "calculated_statement_descriptor": "LITHIC TECHNOLOGY",
              "captured": true,
              "created": 1619548785,
              "currency": "usd",
              "description": "Example charge",
              "destination": null,
              "dispute": null,
              "disputed": false,
              "failure_code": null,
              "failure_message": null,
              "fraud_details": {
              },
              "livemode": false,
              "metadata": {
              },
              "on_behalf_of": null,
              "order": null,
              "outcome": {
                "network_status": "approved_by_network",
                "reason": null,
                "risk_level": "normal",
                "risk_score": 20,
                "seller_message": "Payment complete.",
                "type": "authorized"
              },
              "paid": true,
              "payment_intent": null,
              "payment_method": "card_1IkvozFFYxHXGyKxpLVmZO9x",
              "payment_method_details": {
                "card": {
                  "brand": "visa",
                  "checks": {
                    "address_line1_check": null,
                    "address_postal_code_check": null,
                    "cvc_check": null
                  },
                  "country": "US",
                  "exp_month": 4,
                  "exp_year": 2022,
                  "fingerprint": "t6Eo2YGsl3ZPivuR",
                  "funding": "credit",
                  "installments": null,
                  "last4": "4242",
                  "network": "visa",
                  "three_d_secure": null,
                  "wallet": null
                },
                "type": "card"
              },
              "receipt_email": null,
              "receipt_number": null,
              "receipt_url": "https://pay.stripe.com/receipts/acct_1F6kGvFFYxHXGyKx/ch_1IkvozFFYxHXGyKxDwTuyLZq/rcpt_JNhDs8y3JGTTzdhEAsp1sZNYC0l1dNm",
              "refunded": false,
              "refunds": {
                "object": "list",
                "data": [
                ],
                "has_more": false,
                "total_count": 0,
                "url": "/v1/charges/ch_1IkvozFFYxHXGyKxDwTuyLZq/refunds"
              },
              "review": null,
              "shipping": null,
              "source": {
                "id": "card_1IkvozFFYxHXGyKxpLVmZO9x",
                "object": "card",
                "address_city": null,
                "address_country": null,
                "address_line1": null,
                "address_line1_check": null,
                "address_line2": null,
                "address_state": null,
                "address_zip": null,
                "address_zip_check": null,
                "brand": "Visa",
                "country": "US",
                "customer": null,
                "cvc_check": null,
                "dynamic_last4": null,
                "exp_month": 4,
                "exp_year": 2022,
                "fingerprint": "t6Eo2YGsl3ZPivuR",
                "funding": "credit",
                "last4": "4242",
                "metadata": {
                },
                "name": null,
                "tokenization_method": null
              },
              "source_transfer": null,
              "statement_descriptor": null,
              "statement_descriptor_suffix": null,
              "status": "succeeded",
              "transfer_data": null,
              "transfer_group": null
            }
          },
          "livemode": false,
          "pending_webhooks": 0,
          "request": {
            "id": null,
            "idempotency_key": null
          },
          "type": "source.chargeable"
        }
      J
    end
    let(:expected_data) { body["data"]["object"] }
  end

  it_behaves_like "a replicator that prevents overwriting new data with old" do
    let(:old_body) do
      JSON.parse(<<~J)
        {
          "id": "evt_1CiPtv2eZvKYlo2CcUZsDcO6",
          "object": "event",
          "api_version": "2018-05-21",
          "created": 1530291411,
          "data": {
            "object": {
              "id": "ch_1IkvozFFYxHXGyKxDwTuyLZq",
              "object": "charge",
              "amount": 888,
              "amount_captured": 888,
              "amount_refunded": 0,
              "application": null,
              "application_fee": null,
              "application_fee_amount": null,
              "balance_transaction": "txn_1IkvozFFYxHXGyKxgxXkVSPw",
              "billing_details": {
                "address": {
                  "city": null,
                  "country": null,
                  "line1": null,
                  "line2": null,
                  "postal_code": null,
                  "state": null
                },
                "email": null,
                "name": null,
                "phone": null
              },
              "calculated_statement_descriptor": "LITHIC TECHNOLOGY",
              "captured": true,
              "created": 1619548785,
              "currency": "usd",
              "customer": null,
              "description": "Example charge",
              "destination": null,
              "dispute": null,
              "disputed": false,
              "failure_code": null,
              "failure_message": null,
              "fraud_details": {
              },
              "invoice": null,
              "livemode": false,
              "metadata": {
              },
              "on_behalf_of": null,
              "order": null,
              "outcome": {
                "network_status": "approved_by_network",
                "reason": null,
                "risk_level": "normal",
                "risk_score": 20,
                "seller_message": "Payment complete.",
                "type": "authorized"
              },
              "paid": true,
              "payment_intent": null,
              "payment_method": "card_1IkvozFFYxHXGyKxpLVmZO9x",
              "payment_method_details": {
                "card": {
                  "brand": "visa",
                  "checks": {
                    "address_line1_check": null,
                    "address_postal_code_check": null,
                    "cvc_check": null
                  },
                  "country": "US",
                  "exp_month": 4,
                  "exp_year": 2022,
                  "fingerprint": "t6Eo2YGsl3ZPivuR",
                  "funding": "credit",
                  "installments": null,
                  "last4": "4242",
                  "network": "visa",
                  "three_d_secure": null,
                  "wallet": null
                },
                "type": "card"
              },
              "receipt_email": null,
              "receipt_number": null,
              "receipt_url": "https://pay.stripe.com/receipts/acct_1F6kGvFFYxHXGyKx/ch_1IkvozFFYxHXGyKxDwTuyLZq/rcpt_JNhDs8y3JGTTzdhEAsp1sZNYC0l1dNm",
              "refunded": false,
              "refunds": {
                "object": "list",
                "data": [
                ],
                "has_more": false,
                "total_count": 0,
                "url": "/v1/charges/ch_1IkvozFFYxHXGyKxDwTuyLZq/refunds"
              },
              "review": null,
              "shipping": null,
              "source": {
                "id": "card_1IkvozFFYxHXGyKxpLVmZO9x",
                "object": "card",
                "address_city": null,
                "address_country": null,
                "address_line1": null,
                "address_line1_check": null,
                "address_line2": null,
                "address_state": null,
                "address_zip": null,
                "address_zip_check": null,
                "brand": "Visa",
                "country": "US",
                "customer": null,
                "cvc_check": null,
                "dynamic_last4": null,
                "exp_month": 4,
                "exp_year": 2022,
                "fingerprint": "t6Eo2YGsl3ZPivuR",
                "funding": "credit",
                "last4": "4242",
                "metadata": {
                },
                "name": null,
                "tokenization_method": null
              },
              "source_transfer": null,
              "statement_descriptor": null,
              "statement_descriptor_suffix": null,
              "status": "succeeded",
              "transfer_data": null,
              "transfer_group": null
            }
          },
          "livemode": false,
          "pending_webhooks": 0,
          "request": {
            "id": null,
            "idempotency_key": null
          },
          "type": "source.chargeable"
        }
      J
    end
    let(:new_body) do
      JSON.parse(<<~J)
        {
          "id": "evt_1CiPtv2eZvKYlo2CcUZsDcO6",
          "object": "event",
          "api_version": "2018-05-21",
          "created": 1530300000,
          "data": {
            "object": {
              "id": "ch_1IkvozFFYxHXGyKxDwTuyLZq",
              "object": "charge",
              "amount": 888,
              "amount_captured": 888,
              "amount_refunded": 0,
              "application": null,
              "application_fee": null,
              "application_fee_amount": null,
              "balance_transaction": "txn_1IkvozFFYxHXGyKxgxXkVSPw",
              "billing_details": {
                "address": {
                  "city": null,
                  "country": null,
                  "line1": null,
                  "line2": null,
                  "postal_code": null,
                  "state": null
                },
                "email": null,
                "name": null,
                "phone": null
              },
              "calculated_statement_descriptor": "LITHIC TECHNOLOGY",
              "captured": true,
              "created": 1619548785,
              "currency": "usd",
              "customer": null,
              "description": "Example charge",
              "destination": null,
              "dispute": null,
              "disputed": false,
              "failure_code": null,
              "failure_message": null,
              "fraud_details": {
              },
              "invoice": null,
              "livemode": false,
              "metadata": {
              },
              "on_behalf_of": null,
              "order": null,
              "outcome": {
                "network_status": "approved_by_network",
                "reason": null,
                "risk_level": "normal",
                "risk_score": 20,
                "seller_message": "Payment complete.",
                "type": "authorized"
              },
              "paid": true,
              "payment_intent": null,
              "payment_method": "card_1IkvozFFYxHXGyKxpLVmZO9x",
              "payment_method_details": {
                "card": {
                  "brand": "visa",
                  "checks": {
                    "address_line1_check": null,
                    "address_postal_code_check": null,
                    "cvc_check": null
                  },
                  "country": "US",
                  "exp_month": 4,
                  "exp_year": 2022,
                  "fingerprint": "t6Eo2YGsl3ZPivuR",
                  "funding": "credit",
                  "installments": null,
                  "last4": "4242",
                  "network": "visa",
                  "three_d_secure": null,
                  "wallet": null
                },
                "type": "card"
              },
              "receipt_email": null,
              "receipt_number": null,
              "receipt_url": "https://pay.stripe.com/receipts/acct_1F6kGvFFYxHXGyKx/ch_1IkvozFFYxHXGyKxDwTuyLZq/rcpt_JNhDs8y3JGTTzdhEAsp1sZNYC0l1dNm",
              "refunded": false,
              "refunds": {
                "object": "list",
                "data": [
                ],
                "has_more": false,
                "total_count": 0,
                "url": "/v1/charges/ch_1IkvozFFYxHXGyKxDwTuyLZq/refunds"
              },
              "review": null,
              "shipping": null,
              "source": {
                "id": "card_1IkvozFFYxHXGyKxpLVmZO9x",
                "object": "card",
                "address_city": null,
                "address_country": null,
                "address_line1": null,
                "address_line1_check": null,
                "address_line2": null,
                "address_state": null,
                "address_zip": null,
                "address_zip_check": null,
                "brand": "Visa",
                "country": "US",
                "customer": null,
                "cvc_check": null,
                "dynamic_last4": null,
                "exp_month": 4,
                "exp_year": 2022,
                "fingerprint": "t6Eo2YGsl3ZPivuR",
                "funding": "credit",
                "last4": "4242",
                "metadata": {
                },
                "name": null,
                "tokenization_method": null
              },
              "source_transfer": null,
              "statement_descriptor": null,
              "statement_descriptor_suffix": null,
              "status": "succeeded",
              "transfer_data": null,
              "transfer_group": null
            }
          },
          "livemode": false,
          "pending_webhooks": 0,
          "request": {
            "id": null,
            "idempotency_key": null
          },
          "type": "source.chargeable"
        }
      J
    end
    let(:expected_old_data) { old_body["data"]["object"] }
    let(:expected_new_data) { new_body["data"]["object"] }
  end

  it_behaves_like "a replicator that deals with resources and wrapped events" do
    let(:resource_json) { resource_in_envelope_json.dig("data", "object") }
    let(:resource_in_envelope_json) do
      JSON.parse(<<~J)
        {
          "id": "evt_1CiPtv2eZvKYlo2CcUZsDcO6",
          "object": "event",
          "api_version": "2018-05-21",
          "created": 1530291411,
          "data": {
            "object": {
              "id": "ch_1IkvozFFYxHXGyKxDwTuyLZq",
              "object": "charge",
              "amount": 888,
              "amount_captured": 888,
              "amount_refunded": 0,
              "application": null,
              "application_fee": null,
              "application_fee_amount": null,
              "balance_transaction": "txn_1IkvozFFYxHXGyKxgxXkVSPw",
              "billing_details": {
                "address": {
                  "city": null,
                  "country": null,
                  "line1": null,
                  "line2": null,
                  "postal_code": null,
                  "state": null
                },
                "email": null,
                "name": null,
                "phone": null
              },
              "calculated_statement_descriptor": "LITHIC TECHNOLOGY",
              "captured": true,
              "created": 1619548785,
              "currency": "usd",
              "description": "Example charge",
              "destination": null,
              "dispute": null,
              "disputed": false,
              "failure_code": null,
              "failure_message": null,
              "fraud_details": {
              },
              "livemode": false,
              "metadata": {
              },
              "on_behalf_of": null,
              "order": null,
              "outcome": {
                "network_status": "approved_by_network",
                "reason": null,
                "risk_level": "normal",
                "risk_score": 20,
                "seller_message": "Payment complete.",
                "type": "authorized"
              },
              "paid": true,
              "payment_intent": null,
              "payment_method": "card_1IkvozFFYxHXGyKxpLVmZO9x",
              "payment_method_details": {
                "card": {
                  "brand": "visa",
                  "checks": {
                    "address_line1_check": null,
                    "address_postal_code_check": null,
                    "cvc_check": null
                  },
                  "country": "US",
                  "exp_month": 4,
                  "exp_year": 2022,
                  "fingerprint": "t6Eo2YGsl3ZPivuR",
                  "funding": "credit",
                  "installments": null,
                  "last4": "4242",
                  "network": "visa",
                  "three_d_secure": null,
                  "wallet": null
                },
                "type": "card"
              },
              "receipt_email": null,
              "receipt_number": null,
              "receipt_url": "https://pay.stripe.com/receipts/acct_1F6kGvFFYxHXGyKx/ch_1IkvozFFYxHXGyKxDwTuyLZq/rcpt_JNhDs8y3JGTTzdhEAsp1sZNYC0l1dNm",
              "refunded": false,
              "refunds": {
                "object": "list",
                "data": [
                ],
                "has_more": false,
                "total_count": 0,
                "url": "/v1/charges/ch_1IkvozFFYxHXGyKxDwTuyLZq/refunds"
              },
              "review": null,
              "shipping": null,
              "source": {
                "id": "card_1IkvozFFYxHXGyKxpLVmZO9x",
                "object": "card",
                "address_city": null,
                "address_country": null,
                "address_line1": null,
                "address_line1_check": null,
                "address_line2": null,
                "address_state": null,
                "address_zip": null,
                "address_zip_check": null,
                "brand": "Visa",
                "country": "US",
                "customer": null,
                "cvc_check": null,
                "dynamic_last4": null,
                "exp_month": 4,
                "exp_year": 2022,
                "fingerprint": "t6Eo2YGsl3ZPivuR",
                "funding": "credit",
                "last4": "4242",
                "metadata": {
                },
                "name": null,
                "tokenization_method": null
              },
              "source_transfer": null,
              "statement_descriptor": null,
              "statement_descriptor_suffix": null,
              "status": "succeeded",
              "transfer_data": null,
              "transfer_group": null
            }
          },
          "livemode": false,
          "pending_webhooks": 0,
          "request": {
            "id": null,
            "idempotency_key": null
          },
          "type": "source.chargeable"
        }
      J
    end
  end

  it_behaves_like "a replicator that verifies backfill secrets" do
    let(:correct_creds_sint) do
      Webhookdb::Fixtures.service_integration.create(
        service_name: "stripe_charge_v1",
        backfill_key: "bfkey",
      )
    end
    let(:incorrect_creds_sint) do
      Webhookdb::Fixtures.service_integration.create(
        service_name: "stripe_charge_v1",
        backfill_key: "bfkey_wrong",
      )
    end

    let(:failed_step_matchers) do
      {output: include("Something is wrong with your configuration"), prompt_is_secret: true}
    end

    let(:success_body) do
      <<~R
        {
          "object": "list",
          "data": [],
          "has_more": false,
          "url": "/v1/charges"
        }
      R
    end
    def stub_service_request
      return stub_request(:get, "https://api.stripe.com/v1/charges").
          with(headers: {"Authorization" => "Basic YmZrZXk6"}).
          to_return(status: 200, body: success_body, headers: {})
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.stripe.com/v1/charges").
          with(headers: {"Authorization" => "Basic YmZrZXlfd3Jvbmc6"}).
          to_return(status: 401, body: "", headers: {})
    end
  end

  it_behaves_like "a replicator that can backfill" do
    let(:page1_response) do
      <<~R
        {
          "data": [
            {
              "amount": 888,
              "amount_captured": 888,
              "amount_refunded": 0,
              "application": null,
              "application_fee": null,
              "application_fee_amount": null,
              "balance_transaction": "txn_1IkvoaFFYxHXGyKxmrsCulwF",
              "calculated_statement_descriptor": "LITHIC TECHNOLOGY",
              "captured": true,
              "created": 1619548759,
              "currency": "usd",
              "customer": null,
              "description": "Example charge",
              "destination": null,
              "dispute": null,
              "disputed": false,
              "failure_code": null,
              "failure_message": null,
              "fraud_details": {},
              "id": "ch_1IkvoZFFYxHXGyKxyM7TyX7o",
              "invoice": null,
              "livemode": false,
              "metadata": {},
              "object": "charge",
              "on_behalf_of": null,
              "order": null,
              "outcome": {
                "network_status": "approved_by_network",
                "reason": null,
                "risk_level": "normal",
                "risk_score": 31,
                "seller_message": "Payment complete.",
                "type": "authorized"
              },
              "paid": true,
              "payment_intent": null,
              "payment_method": "card_1IkvoZFFYxHXGyKxX8thbCNS",
              "payment_method_details": {
                "card": {
                  "brand": "visa",
                  "checks": {
                    "address_line1_check": null,
                    "address_postal_code_check": null,
                    "cvc_check": null
                  },
                  "country": "US",
                  "exp_month": 4,
                  "exp_year": 2022,
                  "fingerprint": "t6Eo2YGsl3ZPivuR",
                  "funding": "credit",
                  "installments": null,
                  "last4": "4242",
                  "network": "visa",
                  "three_d_secure": null,
                  "wallet": null
                },
                "type": "card"
              },
              "receipt_email": null,
              "receipt_number": null,
              "receipt_url": "https://pay.stripe.com/receipts/acct_1F6kGvFFYxHXGyKx/ch_1IkvoZFFYxHXGyKxyM7TyX7o/rcpt_JNhCwaD4a1TNAukoJ0v3biqWr5vxpkq",
              "refunded": false,
              "refunds": {
                "data": [],
                "has_more": false,
                "object": "list",
                "total_count": 0,
                "url": "/v1/charges/ch_1IkvoZFFYxHXGyKxyM7TyX7o/refunds"
              },
              "review": null,
              "shipping": null,
              "source": {
                "address_city": null,
                "address_country": null,
                "address_line1": null,
                "address_line1_check": null,
                "address_line2": null,
                "address_state": null,
                "address_zip": null,
                "address_zip_check": null,
                "brand": "Visa",
                "country": "US",
                "customer": null,
                "cvc_check": null,
                "dynamic_last4": null,
                "exp_month": 4,
                "exp_year": 2022,
                "fingerprint": "t6Eo2YGsl3ZPivuR",
                "funding": "credit",
                "id": "card_1IkvoZFFYxHXGyKxX8thbCNS",
                "last4": "4242",
                "metadata": {},
                "name": null,
                "object": "card",
                "tokenization_method": null
              },
              "source_transfer": null,
              "statement_descriptor": null,
              "statement_descriptor_suffix": null,
              "status": "succeeded",
              "transfer_data": null,
              "transfer_group": null
            },
            {
              "amount": 888,
              "amount_captured": 888,
              "amount_refunded": 0,
              "application": null,
              "application_fee": null,
              "application_fee_amount": null,
              "balance_transaction": "txn_1IkvobFFYxHXGyKxbcCY1TTz",
              "billing_details": {
                "address": {
                  "city": null,
                  "country": null,
                  "line1": null,
                  "line2": null,
                  "postal_code": null,
                  "state": null
                },
                "email": null,
                "name": null,
                "phone": null
              },
              "calculated_statement_descriptor": "LITHIC TECHNOLOGY",
              "captured": true,
              "created": 1619548761,
              "currency": "usd",
              "customer": null,
              "description": "Example charge",
              "destination": null,
              "dispute": null,
              "disputed": false,
              "failure_code": null,
              "failure_message": null,
              "fraud_details": {},
              "id": "ch_1IkvobFFYxHXGyKxDicuMMZe",
              "invoice": null,
              "livemode": false,
              "metadata": {},
              "object": "charge",
              "on_behalf_of": null,
              "order": null,
              "outcome": {
                "network_status": "approved_by_network",
                "reason": null,
                "risk_level": "normal",
                "risk_score": 36,
                "seller_message": "Payment complete.",
                "type": "authorized"
              },
              "paid": true,
              "payment_intent": null,
              "payment_method": "card_1IkvobFFYxHXGyKxLcDbUCSX",
              "payment_method_details": {
                "card": {
                  "brand": "visa",
                  "checks": {
                    "address_line1_check": null,
                    "address_postal_code_check": null,
                    "cvc_check": null
                  },
                  "country": "US",
                  "exp_month": 4,
                  "exp_year": 2022,
                  "fingerprint": "t6Eo2YGsl3ZPivuR",
                  "funding": "credit",
                  "installments": null,
                  "last4": "4242",
                  "network": "visa",
                  "three_d_secure": null,
                  "wallet": null
                },
                "type": "card"
              },
              "receipt_email": null,
              "receipt_number": null,
              "receipt_url": "https://pay.stripe.com/receipts/acct_1F6kGvFFYxHXGyKx/ch_1IkvobFFYxHXGyKxDicuMMZe/rcpt_JNhDesGZQ4kA1bAz7f3bSPfM1mWzHGs",
              "refunded": false,
              "refunds": {
                "data": [],
                "has_more": false,
                "object": "list",
                "total_count": 0,
                "url": "/v1/charges/ch_1IkvobFFYxHXGyKxDicuMMZe/refunds"
              },
              "review": null,
              "shipping": null,
              "source": {
                "address_city": null,
                "address_country": null,
                "address_line1": null,
                "address_line1_check": null,
                "address_line2": null,
                "address_state": null,
                "address_zip": null,
                "address_zip_check": null,
                "brand": "Visa",
                "country": "US",
                "customer": null,
                "cvc_check": null,
                "dynamic_last4": null,
                "exp_month": 4,
                "exp_year": 2022,
                "fingerprint": "t6Eo2YGsl3ZPivuR",
                "funding": "credit",
                "id": "card_1IkvobFFYxHXGyKxLcDbUCSX",
                "last4": "4242",
                "metadata": {},
                "name": null,
                "object": "card",
                "tokenization_method": null
              },
              "source_transfer": null,
              "statement_descriptor": null,
              "statement_descriptor_suffix": null,
              "status": "succeeded",
              "transfer_data": null,
              "transfer_group": null
            },
            {
              "amount": 888,
              "amount_captured": 888,
              "amount_refunded": 0,
              "application": null,
              "application_fee": null,
              "application_fee_amount": null,
              "balance_transaction": "txn_1IkvodFFYxHXGyKxOhdQBfS8",
              "billing_details": {
                "address": {
                  "city": null,
                  "country": null,
                  "line1": null,
                  "line2": null,
                  "postal_code": null,
                  "state": null
                },
                "email": null,
                "name": null,
                "phone": null
              },
              "calculated_statement_descriptor": "LITHIC TECHNOLOGY",
              "captured": true,
              "created": 1619548763,
              "currency": "usd",
              "customer": null,
              "description": "Example charge",
              "destination": null,
              "dispute": null,
              "disputed": false,
              "failure_code": null,
              "failure_message": null,
              "fraud_details": {},
              "id": "ch_1IkvodFFYxHXGyKxEB7b98Q7",
              "invoice": null,
              "livemode": false,
              "metadata": {},
              "object": "charge",
              "on_behalf_of": null,
              "order": null,
              "outcome": {
                "network_status": "approved_by_network",
                "reason": null,
                "risk_level": "normal",
                "risk_score": 3,
                "seller_message": "Payment complete.",
                "type": "authorized"
              },
              "paid": true,
              "payment_intent": null,
              "payment_method": "card_1IkvodFFYxHXGyKxQpGHCUXy",
              "payment_method_details": {
                "card": {
                  "brand": "visa",
                  "checks": {
                    "address_line1_check": null,
                    "address_postal_code_check": null,
                    "cvc_check": null
                  },
                  "country": "US",
                  "exp_month": 4,
                  "exp_year": 2022,
                  "fingerprint": "t6Eo2YGsl3ZPivuR",
                  "funding": "credit",
                  "installments": null,
                  "last4": "4242",
                  "network": "visa",
                  "three_d_secure": null,
                  "wallet": null
                },
                "type": "card"
              },
              "receipt_email": null,
              "receipt_number": null,
              "receipt_url": "https://pay.stripe.com/receipts/acct_1F6kGvFFYxHXGyKx/ch_1IkvodFFYxHXGyKxEB7b98Q7/rcpt_JNhDsOnEau0DRG8GoiVlfyIKVydtrBX",
              "refunded": false,
              "refunds": {
                "data": [],
                "has_more": false,
                "object": "list",
                "total_count": 0,
                "url": "/v1/charges/ch_1IkvodFFYxHXGyKxEB7b98Q7/refunds"
              },
              "review": null,
              "shipping": null,
              "source": {
                "address_city": null,
                "address_country": null,
                "address_line1": null,
                "address_line1_check": null,
                "address_line2": null,
                "address_state": null,
                "address_zip": null,
                "address_zip_check": null,
                "brand": "Visa",
                "country": "US",
                "customer": null,
                "cvc_check": null,
                "dynamic_last4": null,
                "exp_month": 4,
                "exp_year": 2022,
                "fingerprint": "t6Eo2YGsl3ZPivuR",
                "funding": "credit",
                "id": "card_1IkvodFFYxHXGyKxQpGHCUXy",
                "last4": "4242",
                "metadata": {},
                "name": null,
                "object": "card",
                "tokenization_method": null
              },
              "source_transfer": null,
              "statement_descriptor": null,
              "statement_descriptor_suffix": null,
              "status": "succeeded",
              "transfer_data": null,
              "transfer_group": null
            }
          ],
          "has_more": true,
          "object": "list",
          "url": "/v1/charges"
        }
      R
    end
    let(:page2_response) do
      <<~R
        {
          "data": [
            {
              "amount": 888,
              "amount_captured": 888,
              "amount_refunded": 0,
              "application": null,
              "application_fee": null,
              "application_fee_amount": null,
              "balance_transaction": "txn_1IkvogFFYxHXGyKxaCLhrsbF",
              "billing_details": {
                "address": {
                  "city": null,
                  "country": null,
                  "line1": null,
                  "line2": null,
                  "postal_code": null,
                  "state": null
                },
                "email": null,
                "name": null,
                "phone": null
              },
              "calculated_statement_descriptor": "LITHIC TECHNOLOGY",
              "captured": true,
              "created": 1619548765,
              "currency": "usd",
              "customer": null,
              "description": "Example charge",
              "destination": null,
              "dispute": null,
              "disputed": false,
              "failure_code": null,
              "failure_message": null,
              "fraud_details": {},
              "id": "ch_1IkvofFFYxHXGyKxShO9rigx",
              "invoice": null,
              "livemode": false,
              "metadata": {},
              "object": "charge",
              "on_behalf_of": null,
              "order": null,
              "outcome": {
                "network_status": "approved_by_network",
                "reason": null,
                "risk_level": "normal",
                "risk_score": 46,
                "seller_message": "Payment complete.",
                "type": "authorized"
              },
              "paid": true,
              "payment_intent": null,
              "payment_method": "card_1IkvofFFYxHXGyKxh69kbePC",
              "payment_method_details": {
                "card": {
                  "brand": "visa",
                  "checks": {
                    "address_line1_check": null,
                    "address_postal_code_check": null,
                    "cvc_check": null
                  },
                  "country": "US",
                  "exp_month": 4,
                  "exp_year": 2022,
                  "fingerprint": "t6Eo2YGsl3ZPivuR",
                  "funding": "credit",
                  "installments": null,
                  "last4": "4242",
                  "network": "visa",
                  "three_d_secure": null,
                  "wallet": null
                },
                "type": "card"
              },
              "receipt_email": null,
              "receipt_number": null,
              "receipt_url": "https://pay.stripe.com/receipts/acct_1F6kGvFFYxHXGyKx/ch_1IkvofFFYxHXGyKxShO9rigx/rcpt_JNhDoIiGVZqAnc7Bzd1cW6sSOHCWi5P",
              "refunded": false,
              "refunds": {
                "data": [],
                "has_more": false,
                "object": "list",
                "total_count": 0,
                "url": "/v1/charges/ch_1IkvofFFYxHXGyKxShO9rigx/refunds"
              },
              "review": null,
              "shipping": null,
              "source": {
                "address_city": null,
                "address_country": null,
                "address_line1": null,
                "address_line1_check": null,
                "address_line2": null,
                "address_state": null,
                "address_zip": null,
                "address_zip_check": null,
                "brand": "Visa",
                "country": "US",
                "customer": null,
                "cvc_check": null,
                "dynamic_last4": null,
                "exp_month": 4,
                "exp_year": 2022,
                "fingerprint": "t6Eo2YGsl3ZPivuR",
                "funding": "credit",
                "id": "card_1IkvofFFYxHXGyKxh69kbePC",
                "last4": "4242",
                "metadata": {},
                "name": null,
                "object": "card",
                "tokenization_method": null
              },
              "source_transfer": null,
              "statement_descriptor": null,
              "statement_descriptor_suffix": null,
              "status": "succeeded",
              "transfer_data": null,
              "transfer_group": null
            },
            {
              "amount": 888,
              "amount_captured": 888,
              "amount_refunded": 0,
              "application": null,
              "application_fee": null,
              "application_fee_amount": null,
              "balance_transaction": "txn_1IkvopFFYxHXGyKxUCCRBi2K",
              "billing_details": {
                "address": {
                  "city": null,
                  "country": null,
                  "line1": null,
                  "line2": null,
                  "postal_code": null,
                  "state": null
                },
                "email": null,
                "name": null,
                "phone": null
              },
              "calculated_statement_descriptor": "LITHIC TECHNOLOGY",
              "captured": true,
              "created": 1619548775,
              "currency": "usd",
              "customer": null,
              "description": "Example charge",
              "destination": null,
              "dispute": null,
              "disputed": false,
              "failure_code": null,
              "failure_message": null,
              "fraud_details": {},
              "id": "ch_1IkvopFFYxHXGyKx5PRJ5tAL",
              "invoice": null,
              "livemode": false,
              "metadata": {},
              "object": "charge",
              "on_behalf_of": null,
              "order": null,
              "outcome": {
                "network_status": "approved_by_network",
                "reason": null,
                "risk_level": "normal",
                "risk_score": 45,
                "seller_message": "Payment complete.",
                "type": "authorized"
              },
              "paid": true,
              "payment_intent": null,
              "payment_method": "card_1IkvopFFYxHXGyKxEqLq0gDo",
              "payment_method_details": {
                "card": {
                  "brand": "visa",
                  "checks": {
                    "address_line1_check": null,
                    "address_postal_code_check": null,
                    "cvc_check": null
                  },
                  "country": "US",
                  "exp_month": 4,
                  "exp_year": 2022,
                  "fingerprint": "t6Eo2YGsl3ZPivuR",
                  "funding": "credit",
                  "installments": null,
                  "last4": "4242",
                  "network": "visa",
                  "three_d_secure": null,
                  "wallet": null
                },
                "type": "card"
              },
              "receipt_email": null,
              "receipt_number": null,
              "receipt_url": "https://pay.stripe.com/receipts/acct_1F6kGvFFYxHXGyKx/ch_1IkvopFFYxHXGyKx5PRJ5tAL/rcpt_JNhDn5M8hocn43zsIds1mi27WbHaApY",
              "refunded": false,
              "refunds": {
                "data": [],
                "has_more": false,
                "object": "list",
                "total_count": 0,
                "url": "/v1/charges/ch_1IkvopFFYxHXGyKx5PRJ5tAL/refunds"
              },
              "review": null,
              "shipping": null,
              "source": {
                "address_city": null,
                "address_country": null,
                "address_line1": null,
                "address_line1_check": null,
                "address_line2": null,
                "address_state": null,
                "address_zip": null,
                "address_zip_check": null,
                "brand": "Visa",
                "country": "US",
                "customer": null,
                "cvc_check": null,
                "dynamic_last4": null,
                "exp_month": 4,
                "exp_year": 2022,
                "fingerprint": "t6Eo2YGsl3ZPivuR",
                "funding": "credit",
                "id": "card_1IkvopFFYxHXGyKxEqLq0gDo",
                "last4": "4242",
                "metadata": {},
                "name": null,
                "object": "card",
                "tokenization_method": null
              },
              "source_transfer": null,
              "statement_descriptor": null,
              "statement_descriptor_suffix": null,
              "status": "succeeded",
              "transfer_data": null,
              "transfer_group": null
            },
            {
              "amount": 888,
              "amount_captured": 888,
              "amount_refunded": 0,
              "application": null,
              "application_fee": null,
              "application_fee_amount": null,
              "balance_transaction": "txn_1IkvozFFYxHXGyKxgxXkVSPw",
              "billing_details": {
                "address": {
                  "city": null,
                  "country": null,
                  "line1": null,
                  "line2": null,
                  "postal_code": null,
                  "state": null
                },
                "email": null,
                "name": null,
                "phone": null
              },
              "calculated_statement_descriptor": "LITHIC TECHNOLOGY",
              "captured": true,
              "created": 1619548785,
              "currency": "usd",
              "customer": null,
              "description": "Example charge",
              "destination": null,
              "dispute": null,
              "disputed": false,
              "failure_code": null,
              "failure_message": null,
              "fraud_details": {},
              "id": "ch_1IkvozFFYxHXGyKxDwTuyLZq",
              "invoice": null,
              "livemode": false,
              "metadata": {},
              "object": "charge",
              "on_behalf_of": null,
              "order": null,
              "outcome": {
                "network_status": "approved_by_network",
                "reason": null,
                "risk_level": "normal",
                "risk_score": 20,
                "seller_message": "Payment complete.",
                "type": "authorized"
              },
              "paid": true,
              "payment_intent": null,
              "payment_method": "card_1IkvozFFYxHXGyKxpLVmZO9x",
              "payment_method_details": {
                "card": {
                  "brand": "visa",
                  "checks": {
                    "address_line1_check": null,
                    "address_postal_code_check": null,
                    "cvc_check": null
                  },
                  "country": "US",
                  "exp_month": 4,
                  "exp_year": 2022,
                  "fingerprint": "t6Eo2YGsl3ZPivuR",
                  "funding": "credit",
                  "installments": null,
                  "last4": "4242",
                  "network": "visa",
                  "three_d_secure": null,
                  "wallet": null
                },
                "type": "card"
              },
              "receipt_email": null,
              "receipt_number": null,
              "receipt_url": "https://pay.stripe.com/receipts/acct_1F6kGvFFYxHXGyKx/ch_1IkvozFFYxHXGyKxDwTuyLZq/rcpt_JNhDs8y3JGTTzdhEAsp1sZNYC0l1dNm",
              "refunded": false,
              "refunds": {
                "data": [],
                "has_more": false,
                "object": "list",
                "total_count": 0,
                "url": "/v1/charges/ch_1IkvozFFYxHXGyKxDwTuyLZq/refunds"
              },
              "review": null,
              "shipping": null,
              "source": {
                "address_city": null,
                "address_country": null,
                "address_line1": null,
                "address_line1_check": null,
                "address_line2": null,
                "address_state": null,
                "address_zip": null,
                "address_zip_check": null,
                "brand": "Visa",
                "country": "US",
                "customer": null,
                "cvc_check": null,
                "dynamic_last4": null,
                "exp_month": 4,
                "exp_year": 2022,
                "fingerprint": "t6Eo2YGsl3ZPivuR",
                "funding": "credit",
                "id": "card_1IkvozFFYxHXGyKxpLVmZO9x",
                "last4": "4242",
                "metadata": {},
                "name": null,
                "object": "card",
                "tokenization_method": null
              },
              "source_transfer": null,
              "statement_descriptor": null,
              "statement_descriptor_suffix": null,
              "status": "succeeded",
              "transfer_data": null,
              "transfer_group": null
            }
          ],
          "has_more": true,
          "object": "list",
          "url": "/v1/charges"
        }
      R
    end
    let(:page3_response) do
      <<~R
        {
          "object": "list",
          "data": [],
          "has_more": false,
          "url": "/v1/charges"
        }
      R
    end
    let(:expected_items_count) { 6 }
    def stub_service_requests
      return [
        stub_request(:get, "https://api.stripe.com/v1/charges").
            with(headers: {"Authorization" => "Basic YmZrZXk6"}).
            to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://api.stripe.com/v1/charges?starting_after=ch_1IkvodFFYxHXGyKxEB7b98Q7").
            to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://api.stripe.com/v1/charges?starting_after=ch_1IkvozFFYxHXGyKxDwTuyLZq").
            to_return(status: 200, body: page3_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_empty_requests
      return [
        stub_request(:get, "https://api.stripe.com/v1/charges").
            to_return(status: 200, body: page3_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.stripe.com/v1/charges").
          with(headers: {"Authorization" => "Basic YmZrZXk6"}).to_return(status: 403, body: "went wrong")
    end
  end

  describe "webhook validation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "stripe_charge_v1") }
    let(:svc) { Webhookdb::Replicator.create(sint) }

    it "returns a 401 as per spec if there is no Authorization header" do
      req = fake_request
      data = req.body
      status, headers, _body = svc.webhook_response(req).to_rack
      expect(status).to eq(401)
    end

    it "returns a 401 for an invalid Authorization header" do
      sint.update(webhook_secret: "user:pass")
      req = fake_request(input: '{"data": "asdfghujkl"}')
      data = req.body
      req.add_header("HTTP_STRIPE_SIGNATURE",
                     "t=1492774577,v1=5257a869e7ecebeda32affa62cdca3fa51cad7e77a0e56ff536d0ce8e108d8bd",)
      status, _headers, body = svc.webhook_response(req).to_rack
      expect(status).to eq(401)
      expect(body).to include("invalid hmac")
    end

    it "returns a 202 with a valid Authorization header" do
      sint.update(webhook_secret: "user:pass")
      req = fake_request(input: '{"data": "asdfghujkl"}')
      data = req.body
      timestamp = Time.now
      stripe_signature = "t=" + timestamp.to_i.to_s + ",v1=" # this is the interim value
      stripe_signature += Stripe::Webhook::Signature.compute_signature(timestamp, data, sint.webhook_secret)
      req.add_header("HTTP_STRIPE_SIGNATURE", stripe_signature)
      status, _headers, _body = svc.webhook_response(req).to_rack
      expect(status).to eq(202)
    end
  end

  describe "state machine calculation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "stripe_charge_v1") }
    let(:svc) { Webhookdb::Replicator.create(sint) }

    describe "calculate_webhook_state_machine" do
      it "asks for webhook secret" do
        sm = sint.replicator.calculate_webhook_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: "Paste or type your secret here:",
          prompt_is_secret: true,
          post_to_url: end_with("/service_integrations/#{sint.opaque_id}/transition/webhook_secret"),
          complete: false,
          output: match("We've made an endpoint available for Stripe Charge webhooks:"),
        )
      end

      it "confirms reciept of webhook secret, returns org database info" do
        sint.webhook_secret = "whsec_abcasdf"
        sm = sint.replicator.calculate_webhook_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          prompt: "",
          prompt_is_secret: false,
          post_to_url: "",
          complete: true,
          output: match("Great! WebhookDB is now listening for Stripe Charge webhooks."),
        )
      end
    end

    describe "calculate_backfill_state_machine" do
      let(:success_body) do
        <<~R
          {
            "object": "list",
            "data": [],
            "has_more": false,
            "url": "/v1/charges"
          }
        R
      end

      def stub_service_request
        return stub_request(:get, "https://api.stripe.com/v1/charges").
            with(headers: {"Authorization" => "Basic d2hzZWNfYWJjYXNkZjo="}).
            to_return(status: 200, body: success_body, headers: {})
      end
      it "asks for backfill key" do
        sm = sint.replicator.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: "Paste or type your Restricted Key here:",
          prompt_is_secret: true,
          post_to_url: end_with("/service_integrations/#{sint.opaque_id}/transition/backfill_key"),
          complete: false,
          output: match("In order to backfill Stripe Charges, we need an API key."),
        )
      end

      it "confirms reciept of backfill key, returns org database info" do
        sint.backfill_key = "whsec_abcasdf"
        res = stub_service_request
        sm = sint.replicator.calculate_backfill_state_machine
        expect(res).to have_been_made
        expect(sm).to have_attributes(
          needs_input: false,
          prompt: "",
          prompt_is_secret: false,
          post_to_url: "",
          complete: true,
          output: match("Great! We are going to start backfilling your Stripe Charges."),
        )
      end
    end
  end
end
