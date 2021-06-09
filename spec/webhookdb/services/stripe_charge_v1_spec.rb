# frozen_string_literal: true

require "support/shared_examples_for_services"

RSpec.describe Webhookdb::Services, :db do
  describe "stripe charge v1" do
    it_behaves_like "a service implementation", "stripe_charge_v1" do
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
          #{'          '}
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

    it_behaves_like "a service implementation that prevents overwriting new data with old", "stripe_charge_v1" do
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
          #{'          '}
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
          #{'          '}
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

    it_behaves_like "a service implementation that can backfill", "stripe_charge_v1" do
      let(:today) { Time.parse("2020-11-22T18:00:00Z") }

      let(:page1_items) { [{}, {}, {}] }
      let(:page2_items) { [{}, {}, {}] }
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
                    #{'          '}
        R
      end
      around(:each) do |example|
        Timecop.travel(today) do
          example.run
        end
      end
      before(:each) do
        stub_request(:get, "https://api.stripe.com/v1/charges").
          with(
            headers: {
              "Accept" => "*/*",
              "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
              "Authorization" => "Basic YmZrZXk6",
              "User-Agent" => "Ruby",
            },
          ).
          to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"})
        stub_request(:get, "https://api.stripe.com/v1/charges?starting_after=ch_1IkvodFFYxHXGyKxEB7b98Q7").
          to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"})
        stub_request(:get, "https://api.stripe.com/v1/charges?starting_after=ch_1IkvozFFYxHXGyKxDwTuyLZq").
          to_return(status: 200, body: page3_response, headers: {"Content-Type" => "application/json"})
      end
    end
    describe "webhook validation" do
      let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "stripe_charge_v1") }
      let(:svc) { Webhookdb::Services.service_instance(sint) }

      it "returns a 401 as per spec if there is no Authorization header" do
        req = fake_request
        data = req.body
        status, headers, _body = svc.webhook_response(req)
        expect(status).to eq(401)
      end

      it "returns a 401 for an invalid Authorization header" do
        sint.update(webhook_secret: "user:pass")
        req = fake_request(input: '{"data": "asdfghujkl"}')
        data = req.body
        req.add_header("HTTP_STRIPE_SIGNATURE",
                       "t=1492774577,v1=5257a869e7ecebeda32affa62cdca3fa51cad7e77a0e56ff536d0ce8e108d8bd",)
        status, _headers, body = svc.webhook_response(req)
        expect(status).to eq(401)
        expect(body).to include("invalid hmac")
      end

      it "returns a 200 with a valid Authorization header" do
        sint.update(webhook_secret: "user:pass")
        req = fake_request(input: '{"data": "asdfghujkl"}')
        data = req.body
        timestamp = Time.now
        stripe_signature = "t=" + timestamp.to_i.to_s + ",v1=" # this is the interim value
        stripe_signature += Stripe::Webhook::Signature.compute_signature(timestamp, data, sint.webhook_secret)
        req.add_header("HTTP_STRIPE_SIGNATURE", stripe_signature)
        status, _headers, _body = svc.webhook_response(req)
        expect(status).to eq(200)
      end
    end
    describe "state machine calculation" do
      let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "stripe_charge_v1") }
      let(:svc) { Webhookdb::Services.service_instance(sint) }

      describe "calculate_create_state_machine" do
        it "asks for webhook secret" do
          state_machine = sint.calculate_create_state_machine
          expect(state_machine.needs_input).to eq(true)
          expect(state_machine.prompt).to eq("Paste or type your secret here:")
          expect(state_machine.prompt_is_secret).to eq(true)
          expect(state_machine.post_to_url).to eq("/v1/service_integrations/#{sint.opaque_id}/transition/webhook_secret")
          expect(state_machine.complete).to eq(false)
          expect(state_machine.output).to match("We've made an endpoint available for Stripe Charge webhooks:")
        end

        it "confirms reciept of webhook secret, returns org database info" do
          sint.webhook_secret = "whsec_abcasdf"
          state_machine = sint.calculate_create_state_machine
          expect(state_machine.needs_input).to eq(false)
          expect(state_machine.prompt).to be_nil
          expect(state_machine.prompt_is_secret).to be_nil
          expect(state_machine.post_to_url).to be_nil
          expect(state_machine.complete).to eq(true)
          expect(state_machine.output).to match("Great! WebhookDB is now listening for Stripe Charge webhooks.")
        end
      end
      describe "calculate_backfill_state_machine" do
        it "it asks for backfill secret" do
          state_machine = sint.calculate_backfill_state_machine
          expect(state_machine.needs_input).to eq(true)
          expect(state_machine.prompt).to eq("Paste or type your Restricted Key here:")
          expect(state_machine.prompt_is_secret).to eq(true)
          expect(state_machine.post_to_url).to eq("/v1/service_integrations/#{sint.opaque_id}/transition/backfill_secret")
          expect(state_machine.complete).to eq(false)
          expect(state_machine.output).to match("In order to backfill Stripe Charges, we need an API key.")
        end

        it "confirms reciept of backfill secret, returns org database info" do
          sint.backfill_secret = "whsec_abcasdf"
          state_machine = sint.calculate_backfill_state_machine
          expect(state_machine.needs_input).to eq(false)
          expect(state_machine.prompt).to be_nil
          expect(state_machine.prompt_is_secret).to be_nil
          expect(state_machine.post_to_url).to be_nil
          expect(state_machine.complete).to eq(true)
          expect(state_machine.output).to match(
            "Great! We are going to start backfilling your Stripe Charge information.",
          )
        end
      end
    end
  end
end
