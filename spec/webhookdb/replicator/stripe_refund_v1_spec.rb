# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::StripeRefundV1, :db do
  let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "stripe_refund_v1") }
  let(:svc) { Webhookdb::Replicator.create(sint) }

  it_behaves_like "a replicator" do
    let(:body) do
      JSON.parse(<<~J)
        {
          "id": "evt_3NtYaBLelvCURGkU1t7fcPHS",
          "object": "event",
          "api_version": "2022-08-01",
          "created": 1696030579,
          "data": {
            "object": {
              "id": "ch_3NtYaBLelvCURGkU1YaN66W1",
              "object": "charge",
              "amount": 500,
              "amount_captured": 500,
              "amount_refunded": 500,
              "application": null,
              "application_fee": null,
              "application_fee_amount": null,
              "balance_transaction": "txn_3NtYaBLelvCURGkU1BCGVOvl",
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
                "name": "Emma Chatterton Bentley",
                "phone": null
              },
              "calculated_statement_descriptor": "APP.MYSUMA.ORG",
              "captured": true,
              "created": 1695486087,
              "currency": "usd",
              "customer": "cus_OOZK3PoLrv6OKo",
              "description": "suma charge",
              "destination": null,
              "dispute": null,
              "disputed": false,
              "failure_balance_transaction": null,
              "failure_code": null,
              "failure_message": null,
              "fraud_details": {},
              "invoice": null,
              "livemode": true,
              "metadata": {
                "suma_card_id": "187",
                "suma_member_name": "Anthony ",
                "suma_api_version": "ecb5165c15eb5f3347d6f6e8671c23328d0b1b37",
                "suma_funding_transaction_id": "258",
                "suma_member_id": "305"
              },
              "on_behalf_of": null,
              "order": null,
              "outcome": {
                "network_status": "approved_by_network",
                "reason": null,
                "risk_level": "normal",
                "seller_message": "Payment complete.",
                "type": "authorized"
              },
              "paid": true,
              "payment_intent": null,
              "payment_method": "card_1NlxYSLelvCURGkUz1jK6fI4",
              "payment_method_details": {
                "card": {
                  "amount_authorized": 500,
                  "brand": "visa",
                  "capture_before": 1696090887,
                  "checks": {
                    "address_line1_check": null,
                    "address_postal_code_check": null,
                    "cvc_check": null
                  },
                  "country": "US",
                  "exp_month": 4,
                  "exp_year": 2025,
                  "extended_authorization": {
                    "status": "disabled"
                  },
                  "fingerprint": "fPXf6c34xZ5hoTeP",
                  "funding": "credit",
                  "incremental_authorization": {
                    "status": "unavailable"
                  },
                  "installments": null,
                  "last4": "0521",
                  "mandate": null,
                  "multicapture": {
                    "status": "unavailable"
                  },
                  "network": "visa",
                  "network_token": {
                    "used": true
                  },
                  "overcapture": {
                    "maximum_amount_capturable": 500,
                    "status": "unavailable"
                  },
                  "three_d_secure": null,
                  "wallet": null
                },
                "type": "card"
              },
              "receipt_email": null,
              "receipt_number": null,
              "receipt_url": "https://pay.stripe.com/receipts/payment/CAcQARoXChVhY2N0XzFMeGRoVkxlbHZDVVJHa1Uo877dqAYyBgfGZo5qWjosFjHdWCThoUJmczLAouNpm-Uqsu8V6da8P703JmECbfx4wA63HA2shc90QlI",
              "refunded": true,
              "refunds": {
                "object": "list",
                "data": [
                  {
                    "id": "re_3NtYaBLelvCURGkU1ug4Q86u",
                    "object": "refund",
                    "amount": 500,
                    "balance_transaction": "txn_3NtYaBLelvCURGkU1KLzBUoT",
                    "charge": "ch_3NtYaBLelvCURGkU1YaN66W1",
                    "created": 1696030578,
                    "currency": "usd",
                    "metadata": {},
                    "payment_intent": null,
                    "reason": null,
                    "receipt_number": null,
                    "source_transfer_reversal": null,
                    "status": "succeeded",
                    "transfer_reversal": null
                  }
                ],
                "has_more": false,
                "total_count": 1,
                "url": "/v1/charges/ch_3NtYaBLelvCURGkU1YaN66W1/refunds"
              },
              "review": null,
              "shipping": null,
              "source": {
                "id": "card_1NlxYSLelvCURGkUz1jK6fI4",
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
                "customer": "cus_OOZK3PoLrv6OKo",
                "cvc_check": null,
                "dynamic_last4": null,
                "exp_month": 4,
                "exp_year": 2025,
                "fingerprint": "fPXf6c34xZ5hoTeP",
                "funding": "credit",
                "last4": "0521",
                "metadata": {},
                "name": "Emma Chatterton Bentley",
                "tokenization_method": null,
                "wallet": null
              },
              "source_transfer": null,
              "statement_descriptor": null,
              "statement_descriptor_suffix": null,
              "status": "succeeded",
              "transfer_data": null,
              "transfer_group": null
            },
            "previous_attributes": {
              "amount_refunded": 0,
              "receipt_url": "https://pay.stripe.com/receipts/payment/CAcQARoXChVhY2N0XzFMeGRoVkxlbHZDVVJHa1Uo8r7dqAYyBp7MRAi8VTosFlGpa0xJV1ZtwPh-2F521O-4KLGZPSirF6wWaZOZNgzFAC9EP20P7taPl5Y",
              "refunded": false,
              "refunds": {
                "data": [],
                "total_count": 0
              }
            }
          },
          "livemode": true,
          "pending_webhooks": 2,
          "request": {
            "id": "req_tcrfWYcurAuWzq",
            "idempotency_key": "dfe47d4d-ff64-44cb-850c-6b0c8c9cffc9"
          },
          "type": "charge.refunded"
        }
      J
    end
    let(:expected_data) { body["data"]["object"]["refunds"]["data"][0] }
  end
  it_behaves_like "a replicator that prevents overwriting new data with old" do
    let(:old_body) do
      JSON.parse(<<~J)
        {
          "id": "evt_3NtYaBLelvCURGkU1t7fcPHS",
          "object": "event",
          "api_version": "2022-08-01",
          "created": 1696030579,
          "data": {
            "object": {
              "id": "ch_3NtYaBLelvCURGkU1YaN66W1",
              "object": "charge",
              "amount": 500,
              "amount_captured": 500,
              "amount_refunded": 500,
              "application": null,
              "application_fee": null,
              "application_fee_amount": null,
              "balance_transaction": "txn_3NtYaBLelvCURGkU1BCGVOvl",
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
                "name": "Emma Chatterton Bentley",
                "phone": null
              },
              "calculated_statement_descriptor": "APP.MYSUMA.ORG",
              "captured": true,
              "created": 1695486087,
              "currency": "usd",
              "customer": "cus_OOZK3PoLrv6OKo",
              "description": "suma charge",
              "destination": null,
              "dispute": null,
              "disputed": false,
              "failure_balance_transaction": null,
              "failure_code": null,
              "failure_message": null,
              "fraud_details": {},
              "invoice": null,
              "livemode": true,
              "metadata": {
                "suma_card_id": "187",
                "suma_member_name": "Anthony ",
                "suma_api_version": "ecb5165c15eb5f3347d6f6e8671c23328d0b1b37",
                "suma_funding_transaction_id": "258",
                "suma_member_id": "305"
              },
              "on_behalf_of": null,
              "order": null,
              "outcome": {
                "network_status": "approved_by_network",
                "reason": null,
                "risk_level": "normal",
                "seller_message": "Payment complete.",
                "type": "authorized"
              },
              "paid": true,
              "payment_intent": null,
              "payment_method": "card_1NlxYSLelvCURGkUz1jK6fI4",
              "payment_method_details": {
                "card": {
                  "amount_authorized": 500,
                  "brand": "visa",
                  "capture_before": 1696090887,
                  "checks": {
                    "address_line1_check": null,
                    "address_postal_code_check": null,
                    "cvc_check": null
                  },
                  "country": "US",
                  "exp_month": 4,
                  "exp_year": 2025,
                  "extended_authorization": {
                    "status": "disabled"
                  },
                  "fingerprint": "fPXf6c34xZ5hoTeP",
                  "funding": "credit",
                  "incremental_authorization": {
                    "status": "unavailable"
                  },
                  "installments": null,
                  "last4": "0521",
                  "mandate": null,
                  "multicapture": {
                    "status": "unavailable"
                  },
                  "network": "visa",
                  "network_token": {
                    "used": true
                  },
                  "overcapture": {
                    "maximum_amount_capturable": 500,
                    "status": "unavailable"
                  },
                  "three_d_secure": null,
                  "wallet": null
                },
                "type": "card"
              },
              "receipt_email": null,
              "receipt_number": null,
              "receipt_url": "https://pay.stripe.com/receipts/payment/CAcQARoXChVhY2N0XzFMeGRoVkxlbHZDVVJHa1Uo877dqAYyBgfGZo5qWjosFjHdWCThoUJmczLAouNpm-Uqsu8V6da8P703JmECbfx4wA63HA2shc90QlI",
              "refunded": true,
              "refunds": {
                "object": "list",
                "data": [
                  {
                    "id": "re_3NtYaBLelvCURGkU1ug4Q86u",
                    "object": "refund",
                    "amount": 500,
                    "balance_transaction": "txn_3NtYaBLelvCURGkU1KLzBUoT",
                    "charge": "ch_3NtYaBLelvCURGkU1YaN66W1",
                    "created": 1696030578,
                    "currency": "usd",
                    "metadata": {},
                    "payment_intent": null,
                    "reason": null,
                    "receipt_number": null,
                    "source_transfer_reversal": null,
                    "status": "succeeded",
                    "transfer_reversal": null
                  }
                ],
                "has_more": false,
                "total_count": 1,
                "url": "/v1/charges/ch_3NtYaBLelvCURGkU1YaN66W1/refunds"
              },
              "review": null,
              "shipping": null,
              "source": {
                "id": "card_1NlxYSLelvCURGkUz1jK6fI4",
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
                "customer": "cus_OOZK3PoLrv6OKo",
                "cvc_check": null,
                "dynamic_last4": null,
                "exp_month": 4,
                "exp_year": 2025,
                "fingerprint": "fPXf6c34xZ5hoTeP",
                "funding": "credit",
                "last4": "0521",
                "metadata": {},
                "name": "Emma Chatterton Bentley",
                "tokenization_method": null,
                "wallet": null
              },
              "source_transfer": null,
              "statement_descriptor": null,
              "statement_descriptor_suffix": null,
              "status": "succeeded",
              "transfer_data": null,
              "transfer_group": null
            },
            "previous_attributes": {
              "amount_refunded": 0,
              "receipt_url": "https://pay.stripe.com/receipts/payment/CAcQARoXChVhY2N0XzFMeGRoVkxlbHZDVVJHa1Uo8r7dqAYyBp7MRAi8VTosFlGpa0xJV1ZtwPh-2F521O-4KLGZPSirF6wWaZOZNgzFAC9EP20P7taPl5Y",
              "refunded": false,
              "refunds": {
                "data": [],
                "total_count": 0
              }
            }
          },
          "livemode": true,
          "pending_webhooks": 2,
          "request": {
            "id": "req_tcrfWYcurAuWzq",
            "idempotency_key": "dfe47d4d-ff64-44cb-850c-6b0c8c9cffc9"
          },
          "type": "charge.refunded"
        }
      J
    end

    let(:new_body) do
      JSON.parse(<<~J)
        {
          "id": "evt_3NtYaBLelvCURGkU1t7fcPHS",
          "object": "event",
          "api_version": "2022-08-01",
          "created": 1696030579,
          "data": {
            "object": {
              "id": "ch_3NtYaBLelvCURGkU1YaN66W1",
              "object": "charge",
              "amount": 500,
              "amount_captured": 500,
              "amount_refunded": 500,
              "application": null,
              "application_fee": null,
              "application_fee_amount": null,
              "balance_transaction": "txn_3NtYaBLelvCURGkU1BCGVOvl",
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
                "name": "Emma Chatterton Bentley",
                "phone": null
              },
              "calculated_statement_descriptor": "APP.MYSUMA.ORG",
              "captured": true,
              "created": 1695486087,
              "currency": "usd",
              "customer": "cus_OOZK3PoLrv6OKo",
              "description": "suma charge",
              "destination": null,
              "dispute": null,
              "disputed": false,
              "failure_balance_transaction": null,
              "failure_code": null,
              "failure_message": null,
              "fraud_details": {},
              "invoice": null,
              "livemode": true,
              "metadata": {
                "suma_card_id": "187",
                "suma_member_name": "Anthony ",
                "suma_api_version": "ecb5165c15eb5f3347d6f6e8671c23328d0b1b37",
                "suma_funding_transaction_id": "258",
                "suma_member_id": "305"
              },
              "on_behalf_of": null,
              "order": null,
              "outcome": {
                "network_status": "approved_by_network",
                "reason": null,
                "risk_level": "normal",
                "seller_message": "Payment complete.",
                "type": "authorized"
              },
              "paid": true,
              "payment_intent": null,
              "payment_method": "card_1NlxYSLelvCURGkUz1jK6fI4",
              "payment_method_details": {
                "card": {
                  "amount_authorized": 500,
                  "brand": "visa",
                  "capture_before": 1696090887,
                  "checks": {
                    "address_line1_check": null,
                    "address_postal_code_check": null,
                    "cvc_check": null
                  },
                  "country": "US",
                  "exp_month": 4,
                  "exp_year": 2025,
                  "extended_authorization": {
                    "status": "disabled"
                  },
                  "fingerprint": "fPXf6c34xZ5hoTeP",
                  "funding": "credit",
                  "incremental_authorization": {
                    "status": "unavailable"
                  },
                  "installments": null,
                  "last4": "0521",
                  "mandate": null,
                  "multicapture": {
                    "status": "unavailable"
                  },
                  "network": "visa",
                  "network_token": {
                    "used": true
                  },
                  "overcapture": {
                    "maximum_amount_capturable": 500,
                    "status": "unavailable"
                  },
                  "three_d_secure": null,
                  "wallet": null
                },
                "type": "card"
              },
              "receipt_email": null,
              "receipt_number": null,
              "receipt_url": "https://pay.stripe.com/receipts/payment/CAcQARoXChVhY2N0XzFMeGRoVkxlbHZDVVJHa1Uo877dqAYyBgfGZo5qWjosFjHdWCThoUJmczLAouNpm-Uqsu8V6da8P703JmECbfx4wA63HA2shc90QlI",
              "refunded": true,
              "refunds": {
                "object": "list",
                "data": [
                  {
                    "id": "re_3NtYaBLelvCURGkU1ug4Q86u",
                    "object": "refund",
                    "amount": 500,
                    "balance_transaction": "txn_3NtYaBLelvCURGkU1KLzBUoT",
                    "charge": "ch_3NtYaBLelvCURGkU1YaN66W1",
                    "created": 1696040000,
                    "currency": "usd",
                    "metadata": {},
                    "payment_intent": null,
                    "reason": null,
                    "receipt_number": null,
                    "source_transfer_reversal": null,
                    "status": "succeeded",
                    "transfer_reversal": null
                  }
                ],
                "has_more": false,
                "total_count": 1,
                "url": "/v1/charges/ch_3NtYaBLelvCURGkU1YaN66W1/refunds"
              },
              "review": null,
              "shipping": null,
              "source": {
                "id": "card_1NlxYSLelvCURGkUz1jK6fI4",
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
                "customer": "cus_OOZK3PoLrv6OKo",
                "cvc_check": null,
                "dynamic_last4": null,
                "exp_month": 4,
                "exp_year": 2025,
                "fingerprint": "fPXf6c34xZ5hoTeP",
                "funding": "credit",
                "last4": "0521",
                "metadata": {},
                "name": "Emma Chatterton Bentley",
                "tokenization_method": null,
                "wallet": null
              },
              "source_transfer": null,
              "statement_descriptor": null,
              "statement_descriptor_suffix": null,
              "status": "succeeded",
              "transfer_data": null,
              "transfer_group": null
            },
            "previous_attributes": {
              "amount_refunded": 0,
              "receipt_url": "https://pay.stripe.com/receipts/payment/CAcQARoXChVhY2N0XzFMeGRoVkxlbHZDVVJHa1Uo8r7dqAYyBp7MRAi8VTosFlGpa0xJV1ZtwPh-2F521O-4KLGZPSirF6wWaZOZNgzFAC9EP20P7taPl5Y",
              "refunded": false,
              "refunds": {
                "data": [],
                "total_count": 0
              }
            }
          },
          "livemode": true,
          "pending_webhooks": 2,
          "request": {
            "id": "req_tcrfWYcurAuWzq",
            "idempotency_key": "dfe47d4d-ff64-44cb-850c-6b0c8c9cffc9"
          },
          "type": "charge.refunded"
        }
      J
    end
    let(:expected_old_data) { old_body["data"]["object"]["refunds"]["data"][0] }
    let(:expected_new_data) { new_body["data"]["object"]["refunds"]["data"][0] }
  end

  it_behaves_like "a replicator that deals with resources and wrapped events" do
    let(:resource_in_envelope_json) { refund_event_from_charge }
    let(:resource_json) { refund_event_from_charge["data"]["object"]["refunds"]["data"][0] }
    let(:refund_event_from_charge) do
      JSON.parse(<<~JSON)
        {
          "id": "evt_3NtYaBLelvCURGkU1t7fcPHS",
          "object": "event",
          "api_version": "2022-08-01",
          "created": 1696030579,
          "data": {
            "object": {
              "id": "ch_3NtYaBLelvCURGkU1YaN66W1",
              "object": "charge",
              "amount": 500,
              "amount_captured": 500,
              "amount_refunded": 500,
              "application": null,
              "application_fee": null,
              "application_fee_amount": null,
              "balance_transaction": "txn_3NtYaBLelvCURGkU1BCGVOvl",
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
                "name": "Emma Chatterton Bentley",
                "phone": null
              },
              "calculated_statement_descriptor": "APP.MYSUMA.ORG",
              "captured": true,
              "created": 1695486087,
              "currency": "usd",
              "customer": "cus_OOZK3PoLrv6OKo",
              "description": "suma charge",
              "destination": null,
              "dispute": null,
              "disputed": false,
              "failure_balance_transaction": null,
              "failure_code": null,
              "failure_message": null,
              "fraud_details": {},
              "invoice": null,
              "livemode": true,
              "metadata": {
                "suma_card_id": "187",
                "suma_member_name": "Anthony ",
                "suma_api_version": "ecb5165c15eb5f3347d6f6e8671c23328d0b1b37",
                "suma_funding_transaction_id": "258",
                "suma_member_id": "305"
              },
              "on_behalf_of": null,
              "order": null,
              "outcome": {
                "network_status": "approved_by_network",
                "reason": null,
                "risk_level": "normal",
                "seller_message": "Payment complete.",
                "type": "authorized"
              },
              "paid": true,
              "payment_intent": null,
              "payment_method": "card_1NlxYSLelvCURGkUz1jK6fI4",
              "payment_method_details": {
                "card": {
                  "amount_authorized": 500,
                  "brand": "visa",
                  "capture_before": 1696090887,
                  "checks": {
                    "address_line1_check": null,
                    "address_postal_code_check": null,
                    "cvc_check": null
                  },
                  "country": "US",
                  "exp_month": 4,
                  "exp_year": 2025,
                  "extended_authorization": {
                    "status": "disabled"
                  },
                  "fingerprint": "fPXf6c34xZ5hoTeP",
                  "funding": "credit",
                  "incremental_authorization": {
                    "status": "unavailable"
                  },
                  "installments": null,
                  "last4": "0521",
                  "mandate": null,
                  "multicapture": {
                    "status": "unavailable"
                  },
                  "network": "visa",
                  "network_token": {
                    "used": true
                  },
                  "overcapture": {
                    "maximum_amount_capturable": 500,
                    "status": "unavailable"
                  },
                  "three_d_secure": null,
                  "wallet": null
                },
                "type": "card"
              },
              "receipt_email": null,
              "receipt_number": null,
              "receipt_url": "https://pay.stripe.com/receipts/payment/CAcQARoXChVhY2N0XzFMeGRoVkxlbHZDVVJHa1Uo877dqAYyBgfGZo5qWjosFjHdWCThoUJmczLAouNpm-Uqsu8V6da8P703JmECbfx4wA63HA2shc90QlI",
              "refunded": true,
              "refunds": {
                "object": "list",
                "data": [
                  {
                    "id": "re_3NtYaBLelvCURGkU1ug4Q86u",
                    "object": "refund",
                    "amount": 500,
                    "balance_transaction": "txn_3NtYaBLelvCURGkU1KLzBUoT",
                    "charge": "ch_3NtYaBLelvCURGkU1YaN66W1",
                    "created": 1696030578,
                    "currency": "usd",
                    "metadata": {},
                    "payment_intent": null,
                    "reason": null,
                    "receipt_number": null,
                    "source_transfer_reversal": null,
                    "status": "succeeded",
                    "transfer_reversal": null
                  }
                ],
                "has_more": false,
                "total_count": 1,
                "url": "/v1/charges/ch_3NtYaBLelvCURGkU1YaN66W1/refunds"
              },
              "review": null,
              "shipping": null,
              "source": {
                "id": "card_1NlxYSLelvCURGkUz1jK6fI4",
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
                "customer": "cus_OOZK3PoLrv6OKo",
                "cvc_check": null,
                "dynamic_last4": null,
                "exp_month": 4,
                "exp_year": 2025,
                "fingerprint": "fPXf6c34xZ5hoTeP",
                "funding": "credit",
                "last4": "0521",
                "metadata": {},
                "name": "Emma Chatterton Bentley",
                "tokenization_method": null,
                "wallet": null
              },
              "source_transfer": null,
              "statement_descriptor": null,
              "statement_descriptor_suffix": null,
              "status": "succeeded",
              "transfer_data": null,
              "transfer_group": null
            },
            "previous_attributes": {
              "amount_refunded": 0,
              "receipt_url": "https://pay.stripe.com/receipts/payment/CAcQARoXChVhY2N0XzFMeGRoVkxlbHZDVVJHa1Uo8r7dqAYyBp7MRAi8VTosFlGpa0xJV1ZtwPh-2F521O-4KLGZPSirF6wWaZOZNgzFAC9EP20P7taPl5Y",
              "refunded": false,
              "refunds": {
                "data": [],
                "total_count": 0
              }
            }
          },
          "livemode": true,
          "pending_webhooks": 2,
          "request": {
            "id": "req_tcrfWYcurAuWzq",
            "idempotency_key": "dfe47d4d-ff64-44cb-850c-6b0c8c9cffc9"
          },
          "type": "charge.refunded"
        }
      JSON
    end
  end

  it_behaves_like "a replicator that deals with resources and wrapped events" do
    let(:resource_in_envelope_json) { refund_event }
    let(:resource_json) { refund_event["data"]["object"] }
    let(:refund_event) do
      JSON.parse(<<~JSON)
        {
          "api_version": "2022-08-01",
          "created": 1703684780,
          "data": {
            "object": {
              "amount": 1000,
              "balance_transaction": "txn_3OIj0MLelvCURGkU07tmqITY",
              "charge": "ch_3OIj0MLelvCURGkU0RjyIa6n",
              "created": 1703597496,
              "currency": "usd",
              "destination_details": {
                "card": {
                  "reference": "24011343361000004363200",
                  "reference_status": "available",
                  "reference_type": "acquirer_reference_number",
                  "type": "refund"
                },
                "type": "card"
              },
              "id": "re_3OIj0MLelvCURGkU0FusiZvO",
              "metadata": {},
              "object": "refund",
              "payment_intent": null,
              "reason": null,
              "receipt_number": null,
              "source_transfer_reversal": null,
              "status": "succeeded",
              "transfer_reversal": null
            },
            "previous_attributes": {
              "destination_details": {
                "card": {
                  "reference": null,
                  "reference_status": "pending"
                }
              }
            }
          },
          "id": "evt_3OIj0MLelvCURGkU0zgoGmuL",
          "livemode": true,
          "object": "event",
          "pending_webhooks": 1,
          "request": {
            "id": null,
            "idempotency_key": null
          },
          "type": "charge.refund.updated"
        }
      JSON
    end
  end

  it_behaves_like "a replicator that verifies backfill secrets" do
    let(:correct_creds_sint) do
      Webhookdb::Fixtures.service_integration.create(
        service_name: "stripe_refund_v1",
        backfill_key: "bfkey",
      )
    end
    let(:incorrect_creds_sint) do
      Webhookdb::Fixtures.service_integration.create(
        service_name: "stripe_refund_v1",
        backfill_key: "bfkey_wrong",
      )
    end

    let(:success_body) do
      <<~R
        {
          "object": "list",
          "data": [],
          "has_more": false,
          "url": "/v1/refunds"
        }
      R
    end
    def stub_service_request
      return stub_request(:get, "https://api.stripe.com/v1/refunds").
          with(headers: {"Authorization" => "Basic YmZrZXk6"}).
          to_return(status: 200, body: success_body, headers: {})
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.stripe.com/v1/refunds").
          with(headers: {"Authorization" => "Basic YmZrZXlfd3Jvbmc6"}).
          to_return(status: 403, body: "", headers: {})
    end
  end
  it_behaves_like "a replicator that can backfill" do
    let(:page1_response) do
      <<~R
        {
          "object": "list",
          "data": [
            {
              "id": "re_3Ke0Br2eZvKYlo2C1MfCYAM1",
              "object": "refund",
              "amount": 100,
              "balance_transaction": null,
              "charge": "ch_3Ke0Br2eZvKYlo2C1xhyTWTu",
              "created": 1647449957,
              "currency": "usd",
              "metadata": {},
              "payment_intent": null,
              "reason": null,
              "receipt_number": null,
              "source_transfer_reversal": null,
              "status": "succeeded",
              "transfer_reversal": null
            },
            {
              "id": "re_3Ke0Br2eZvKYlo2C1MfCYAM2",
              "object": "refund",
              "amount": 100,
              "balance_transaction": null,
              "charge": "ch_3Ke0Br2eZvKYlo2C1xhyTWTu",
              "created": 1647449957,
              "currency": "usd",
              "metadata": {},
              "payment_intent": null,
              "reason": null,
              "receipt_number": null,
              "source_transfer_reversal": null,
              "status": "succeeded",
              "transfer_reversal": null
            },
            {
              "id": "re_3Ke0Br2eZvKYlo2C1MfCYAM3",
              "object": "refund",
              "amount": 100,
              "balance_transaction": null,
              "charge": "ch_3Ke0Br2eZvKYlo2C1xhyTWTu",
              "created": 1647449957,
              "currency": "usd",
              "metadata": {},
              "payment_intent": null,
              "reason": null,
              "receipt_number": null,
              "source_transfer_reversal": null,
              "status": "succeeded",
              "transfer_reversal": null
            }
          ],
          "has_more": true,
          "url": "/v1/refunds"
        }
      R
    end
    let(:page2_response) do
      <<~R
        {
          "object": "list",
          "data": [
            {
              "id": "re_3Ke0Br2eZvKYlo2C1MfCYAM4",
              "object": "refund",
              "amount": 100,
              "balance_transaction": null,
              "charge": "ch_3Ke0Br2eZvKYlo2C1xhyTWTu",
              "created": 1647449957,
              "currency": "usd",
              "metadata": {},
              "payment_intent": null,
              "reason": null,
              "receipt_number": null,
              "source_transfer_reversal": null,
              "status": "succeeded",
              "transfer_reversal": null
            },
            {
              "id": "re_3Ke0Br2eZvKYlo2C1MfCYAM5",
              "object": "refund",
              "amount": 100,
              "balance_transaction": null,
              "charge": "ch_3Ke0Br2eZvKYlo2C1xhyTWTu",
              "created": 1647449957,
              "currency": "usd",
              "metadata": {},
              "payment_intent": null,
              "reason": null,
              "receipt_number": null,
              "source_transfer_reversal": null,
              "status": "succeeded",
              "transfer_reversal": null
            },
            {
              "id": "re_3Ke0Br2eZvKYlo2C1MfCYAM6",
              "object": "refund",
              "amount": 100,
              "balance_transaction": null,
              "charge": "ch_3Ke0Br2eZvKYlo2C1xhyTWTu",
              "created": 1647449957,
              "currency": "usd",
              "metadata": {},
              "payment_intent": null,
              "reason": null,
              "receipt_number": null,
              "source_transfer_reversal": null,
              "status": "succeeded",
              "transfer_reversal": null
            }
          ],
          "has_more": true,
          "url": "/v1/refunds"
        }
      R
    end
    let(:page3_response) do
      <<~R
        {
          "object": "list",
          "data": [],
          "has_more": false,
          "url": "/v1/refunds"
        }
      R
    end
    let(:expected_items_count) { 6 }
    def stub_service_requests
      return [
        stub_request(:get, "https://api.stripe.com/v1/refunds").
            with(headers: {"Authorization" => "Basic YmZrZXk6"}).
            to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://api.stripe.com/v1/refunds?starting_after=re_3Ke0Br2eZvKYlo2C1MfCYAM3").
            to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://api.stripe.com/v1/refunds?starting_after=re_3Ke0Br2eZvKYlo2C1MfCYAM6").
            to_return(status: 200, body: page3_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_empty_requests
      return [
        stub_request(:get, "https://api.stripe.com/v1/refunds").
            to_return(status: 200, body: page3_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.stripe.com/v1/refunds").
          to_return(status: 403, body: "uhh")
    end
  end
  describe "webhook validation" do
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
    describe "calculate_webhook_state_machine" do
      it "asks for webhook secret" do
        sm = sint.replicator.calculate_webhook_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: "Paste or type your secret here:",
          prompt_is_secret: true,
          post_to_url: end_with("/service_integrations/#{sint.opaque_id}/transition/webhook_secret"),
          complete: false,
          output: match("We've made an endpoint available for Stripe Refund webhooks:"),
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
          output: match("Great! WebhookDB is now listening for Stripe Refund webhooks."),
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
            "url": "/v1/refunds"
          }
        R
      end

      def stub_service_request
        return stub_request(:get, "https://api.stripe.com/v1/refunds").
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
          output: match("In order to backfill Stripe Refunds, we need an API key."),
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
          output: match("Great! We are going to start backfilling your Stripe Refunds."),
        )
      end
    end
  end

  describe "upsert_webhook" do
    Webhookdb::SpecHelpers::Whdb.setup_upsert_webhook_example(self)

    let(:multiple_refunds_webhook_body) do
      JSON.parse(<<~J)
        {
          "id": "evt_3NtYaBLelvCURGkU1t7fcPHS",
          "object": "event",
          "api_version": "2022-08-01",
          "created": 1696030579,
          "data": {
            "object": {
              "id": "ch_3NtYaBLelvCURGkU1YaN66W1",
              "object": "charge",
              "amount": 500,
              "amount_captured": 500,
              "amount_refunded": 500,
              "application": null,
              "application_fee": null,
              "application_fee_amount": null,
              "balance_transaction": "txn_3NtYaBLelvCURGkU1BCGVOvl",
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
                "name": "Emma Chatterton Bentley",
                "phone": null
              },
              "calculated_statement_descriptor": "APP.MYSUMA.ORG",
              "captured": true,
              "created": 1695486087,
              "currency": "usd",
              "customer": "cus_OOZK3PoLrv6OKo",
              "description": "suma charge",
              "destination": null,
              "dispute": null,
              "disputed": false,
              "failure_balance_transaction": null,
              "failure_code": null,
              "failure_message": null,
              "fraud_details": {},
              "invoice": null,
              "livemode": true,
              "metadata": {
                "suma_card_id": "187",
                "suma_member_name": "Anthony ",
                "suma_api_version": "ecb5165c15eb5f3347d6f6e8671c23328d0b1b37",
                "suma_funding_transaction_id": "258",
                "suma_member_id": "305"
              },
              "on_behalf_of": null,
              "order": null,
              "outcome": {
                "network_status": "approved_by_network",
                "reason": null,
                "risk_level": "normal",
                "seller_message": "Payment complete.",
                "type": "authorized"
              },
              "paid": true,
              "payment_intent": null,
              "payment_method": "card_1NlxYSLelvCURGkUz1jK6fI4",
              "payment_method_details": {
                "card": {
                  "amount_authorized": 500,
                  "brand": "visa",
                  "capture_before": 1696090887,
                  "checks": {
                    "address_line1_check": null,
                    "address_postal_code_check": null,
                    "cvc_check": null
                  },
                  "country": "US",
                  "exp_month": 4,
                  "exp_year": 2025,
                  "extended_authorization": {
                    "status": "disabled"
                  },
                  "fingerprint": "fPXf6c34xZ5hoTeP",
                  "funding": "credit",
                  "incremental_authorization": {
                    "status": "unavailable"
                  },
                  "installments": null,
                  "last4": "0521",
                  "mandate": null,
                  "multicapture": {
                    "status": "unavailable"
                  },
                  "network": "visa",
                  "network_token": {
                    "used": true
                  },
                  "overcapture": {
                    "maximum_amount_capturable": 500,
                    "status": "unavailable"
                  },
                  "three_d_secure": null,
                  "wallet": null
                },
                "type": "card"
              },
              "receipt_email": null,
              "receipt_number": null,
              "receipt_url": "https://pay.stripe.com/receipts/payment/CAcQARoXChVhY2N0XzFMeGRoVkxlbHZDVVJHa1Uo877dqAYyBgfGZo5qWjosFjHdWCThoUJmczLAouNpm-Uqsu8V6da8P703JmECbfx4wA63HA2shc90QlI",
              "refunded": true,
              "refunds": {
                "object": "list",
                "data": [
                  {
                    "id": "re_abc123",
                    "object": "refund",
                    "amount": 200,
                    "balance_transaction": "txn_3NtYaBLelvCURGkU1KLzBUoT",
                    "charge": "ch_3NtYaBLelvCURGkU1YaN66W1",
                    "created": 1696030578,
                    "currency": "usd",
                    "metadata": {},
                    "payment_intent": null,
                    "reason": null,
                    "receipt_number": null,
                    "source_transfer_reversal": null,
                    "status": "succeeded",
                    "transfer_reversal": null
                  },#{' '}
                  {
                    "id": "re_def456",
                    "object": "refund",
                    "amount": 300,
                    "balance_transaction": "txn_3NtYaBLelvCURGkU1KLzBUoT",
                    "charge": "ch_3NtYaBLelvCURGkU1YaN66W1",
                    "created": 1696030579,
                    "currency": "usd",
                    "metadata": {},
                    "payment_intent": null,
                    "reason": null,
                    "receipt_number": null,
                    "source_transfer_reversal": null,
                    "status": "succeeded",
                    "transfer_reversal": null
                  }
                ],
                "has_more": true,
                "total_count": 1,
                "url": "/v1/charges/ch_3NtYaBLelvCURGkU1YaN66W1/refunds"
              },
              "review": null,
              "shipping": null,
              "source": {
                "id": "card_1NlxYSLelvCURGkUz1jK6fI4",
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
                "customer": "cus_OOZK3PoLrv6OKo",
                "cvc_check": null,
                "dynamic_last4": null,
                "exp_month": 4,
                "exp_year": 2025,
                "fingerprint": "fPXf6c34xZ5hoTeP",
                "funding": "credit",
                "last4": "0521",
                "metadata": {},
                "name": "Emma Chatterton Bentley",
                "tokenization_method": null,
                "wallet": null
              },
              "source_transfer": null,
              "statement_descriptor": null,
              "statement_descriptor_suffix": null,
              "status": "succeeded",
              "transfer_data": null,
              "transfer_group": null
            },
            "previous_attributes": {
              "amount_refunded": 0,
              "receipt_url": "https://pay.stripe.com/receipts/payment/CAcQARoXChVhY2N0XzFMeGRoVkxlbHZDVVJHa1Uo8r7dqAYyBp7MRAi8VTosFlGpa0xJV1ZtwPh-2F521O-4KLGZPSirF6wWaZOZNgzFAC9EP20P7taPl5Y",
              "refunded": false,
              "refunds": {
                "data": [],
                "total_count": 0
              }
            }
          },
          "livemode": true,
          "pending_webhooks": 2,
          "request": {
            "id": "req_tcrfWYcurAuWzq",
            "idempotency_key": "dfe47d4d-ff64-44cb-850c-6b0c8c9cffc9"
          },
          "type": "charge.refunded"
        }
      J
    end

    before(:each) do
      sint.organization.prepare_database_connections
      svc.create_table
    end

    after(:each) do
      sint.organization.remove_related_database
    end

    it "upserts multiple webhook bodies" do
      upsert_webhook(svc, body: multiple_refunds_webhook_body)
      svc.readonly_dataset do |ds|
        expect(ds.all).to contain_exactly(
          include(stripe_id: "re_abc123", amount: 200),
          include(stripe_id: "re_def456", amount: 300),
        )
      end
    end

    it "emits DeveloperAlert", :async do
      expect do
        upsert_webhook(svc, body: multiple_refunds_webhook_body)
      end.to publish("webhookdb.developeralert.emitted").with_payload(
        contain_exactly(
          {
            "subsystem" => "Stripe Refunds Webhook Error",
            "emoji" => ":hook:",
            "fallback" => "Full backfill required for integration #{sint.opaque_id}",
            "fields" => [],
          },
        ),
      )
    end
  end
end
