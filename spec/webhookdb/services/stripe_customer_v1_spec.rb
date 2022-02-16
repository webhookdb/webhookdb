# frozen_string_literal: true

require "support/shared_examples_for_services"

RSpec.describe Webhookdb::Services::StripeCustomerV1, :db do
  it_behaves_like "a service implementation", "stripe_customer_v1" do
    let(:body) do
      JSON.parse(<<~J)
        {
          "id": "evt_1CiPtv2eZvKYlo2CcUZsDcO6",
          "object": "event",
          "api_version": "2018-05-21",
          "created": 1530291411,
          "data": {
            "object": {
              "id": "cus_FzVfjbZ7ehFJ4a",
              "object": "customer",
              "account_balance": 0,
              "address": null,
              "balance": 0,
              "created": 1571071402,
              "currency": null,
              "default_source": "card_1FTWdhFFYxHXGyKxJEY2Jn4G",
              "delinquent": false,
              "description": "Test User",
              "discount": null,
              "email": "jerica@gerlach.org",
              "invoice_prefix": "200BD30E",
              "invoice_settings": {
                "custom_fields": null,
                "default_payment_method": null,
                "footer": null
              },
              "livemode": false,
              "metadata": {
                "calsync_api_version": "248b9ec2b5aae5aeca41ab86698e92dea81b1e64",
                "calsync_user_id": "56"
              },
              "name": null,
              "next_invoice_sequence": 1,
              "phone": null,
              "preferred_locales": [
              ],
              "shipping": null,
              "sources": {
                "object": "list",
                "data": [
                  {
                    "id": "card_1FTWdhFFYxHXGyKxJEY2Jn4G",
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
                    "customer": "cus_FzVfjbZ7ehFJ4a",
                    "cvc_check": "pass",
                    "dynamic_last4": null,
                    "exp_month": 6,
                    "exp_year": 2022,
                    "fingerprint": "t6Eo2YGsl3ZPivuR",
                    "funding": "credit",
                    "last4": "4242",
                    "metadata": {
                    },
                    "name": null,
                    "tokenization_method": null
                  },
                  {
                    "id": "card_1FTWdjFFYxHXGyKxZKfBNGdJ",
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
                    "customer": "cus_FzVfjbZ7ehFJ4a",
                    "cvc_check": "pass",
                    "dynamic_last4": null,
                    "exp_month": 6,
                    "exp_year": 2022,
                    "fingerprint": "t6Eo2YGsl3ZPivuR",
                    "funding": "credit",
                    "last4": "4242",
                    "metadata": {
                    },
                    "name": null,
                    "tokenization_method": null
                  }
                ],
                "has_more": false,
                "total_count": 2,
                "url": "/v1/customers/cus_FzVfjbZ7ehFJ4a/sources"
              },
              "subscriptions": {
                "object": "list",
                "data": [
                ],
                "has_more": false,
                "total_count": 0,
                "url": "/v1/customers/cus_FzVfjbZ7ehFJ4a/subscriptions"
              },
              "tax_exempt": "none",
              "tax_ids": {
                "object": "list",
                "data": [
                ],
                "has_more": false,
                "total_count": 0,
                "url": "/v1/customers/cus_FzVfjbZ7ehFJ4a/tax_ids"
              },
              "tax_info": null,
              "tax_info_verification": null
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
  it_behaves_like "a service implementation that prevents overwriting new data with old", "stripe_customer_v1" do
    let(:old_body) do
      JSON.parse(<<~J)
        {
          "id": "evt_1CiPtv2eZvKYlo2CcUZsDcO6",
          "object": "event",
          "api_version": "2018-05-21",
          "created": 1530291411,
          "data": {
            "object": {
              "id": "cus_FzVfjbZ7ehFJ4a",
              "object": "customer",
              "account_balance": 0,
              "address": null,
              "balance": 0,
              "created": 1567533323,
              "currency": null,
              "default_source": null,
              "delinquent": false,
              "description": "Test User",
              "discount": null,
              "email": "rosann@ortizdubuque.io",
              "invoice_prefix": "EF2C63AB",
              "invoice_settings": {
                "custom_fields": null,
                "default_payment_method": null,
                "footer": null
              },
              "livemode": false,
              "metadata": {
                "calsync_api_version": "5a9da492108f35fdcdd63c996f6e427abe01e623",
                "calsync_user_id": "29"
              },
              "name": null,
              "next_invoice_sequence": 1,
              "phone": null,
              "preferred_locales": [
              ],
              "shipping": null,
              "sources": {
                "object": "list",
                "data": [
                ],
                "has_more": false,
                "total_count": 0,
                "url": "/v1/customers/cus_FkAZ6RUnwxx45g/sources"
              },
              "subscriptions": {
                "object": "list",
                "data": [
                ],
                "has_more": false,
                "total_count": 0,
                "url": "/v1/customers/cus_FkAZ6RUnwxx45g/subscriptions"
              },
              "tax_exempt": "none",
              "tax_ids": {
                "object": "list",
                "data": [
                ],
                "has_more": false,
                "total_count": 0,
                "url": "/v1/customers/cus_FkAZ6RUnwxx45g/tax_ids"
              },
              "tax_info": null,
              "tax_info_verification": null
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
              "id": "cus_FzVfjbZ7ehFJ4a",
              "object": "customer",
              "account_balance": 0,
              "address": null,
              "balance": 0,
              "created": 1571071402,
              "currency": null,
              "default_source": "card_1FTWdhFFYxHXGyKxJEY2Jn4G",
              "delinquent": false,
              "description": "Test User",
              "discount": null,
              "email": "jerica@gerlach.org",
              "invoice_prefix": "200BD30E",
              "invoice_settings": {
                "custom_fields": null,
                "default_payment_method": null,
                "footer": null
              },
              "livemode": false,
              "metadata": {
                "calsync_api_version": "248b9ec2b5aae5aeca41ab86698e92dea81b1e64",
                "calsync_user_id": "56"
              },
              "name": null,
              "next_invoice_sequence": 1,
              "phone": null,
              "preferred_locales": [
              ],
              "shipping": null,
              "sources": {
                "object": "list",
                "data": [
                  {
                    "id": "card_1FTWdhFFYxHXGyKxJEY2Jn4G",
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
                    "customer": "cus_FzVfjbZ7ehFJ4a",
                    "cvc_check": "pass",
                    "dynamic_last4": null,
                    "exp_month": 6,
                    "exp_year": 2022,
                    "fingerprint": "t6Eo2YGsl3ZPivuR",
                    "funding": "credit",
                    "last4": "4242",
                    "metadata": {
                    },
                    "name": null,
                    "tokenization_method": null
                  },
                  {
                    "id": "card_1FTWdjFFYxHXGyKxZKfBNGdJ",
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
                    "customer": "cus_FzVfjbZ7ehFJ4a",
                    "cvc_check": "pass",
                    "dynamic_last4": null,
                    "exp_month": 6,
                    "exp_year": 2022,
                    "fingerprint": "t6Eo2YGsl3ZPivuR",
                    "funding": "credit",
                    "last4": "4242",
                    "metadata": {
                    },
                    "name": null,
                    "tokenization_method": null
                  }
                ],
                "has_more": false,
                "total_count": 2,
                "url": "/v1/customers/cus_FzVfjbZ7ehFJ4a/sources"
              },
              "subscriptions": {
                "object": "list",
                "data": [
                ],
                "has_more": false,
                "total_count": 0,
                "url": "/v1/customers/cus_FzVfjbZ7ehFJ4a/subscriptions"
              },
              "tax_exempt": "none",
              "tax_ids": {
                "object": "list",
                "data": [
                ],
                "has_more": false,
                "total_count": 0,
                "url": "/v1/customers/cus_FzVfjbZ7ehFJ4a/tax_ids"
              },
              "tax_info": null,
              "tax_info_verification": null
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
  it_behaves_like "a service implementation that verifies backfill secrets" do
    let(:correct_creds_sint) do
      Webhookdb::Fixtures.service_integration.create(
        service_name: "stripe_customer_v1",
        backfill_key: "bfkey",
      )
    end
    let(:incorrect_creds_sint) do
      Webhookdb::Fixtures.service_integration.create(
        service_name: "stripe_customer_v1",
        backfill_key: "bfkey_wrong",
      )
    end

    let(:success_body) do
      <<~R
        {
          "object": "list",
          "data": [],
          "has_more": false,
          "url": "/v1/customers"
        }
      R
    end
    def stub_service_request
      return stub_request(:get, "https://api.stripe.com/v1/customers").
          with(headers: {"Authorization" => "Basic YmZrZXk6"}).
          to_return(status: 200, body: success_body, headers: {})
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.stripe.com/v1/customers").
          with(headers: {"Authorization" => "Basic YmZrZXlfd3Jvbmc6"}).
          to_return(status: 403, body: "", headers: {})
    end
  end
  it_behaves_like "a service implementation that can backfill", "stripe_customer_v1" do
    let(:page1_response) do
      <<~R
        {
          "object": "list",
          "data": [
            {
              "id": "cus_FkAZ6RUnwxx45g",
              "object": "customer",
              "account_balance": 0,
              "address": null,
              "balance": 0,
              "created": 1567533323,
              "currency": null,
              "default_source": null,
              "delinquent": false,
              "description": "Test User",
              "discount": null,
              "email": "rosann@ortizdubuque.io",
              "invoice_prefix": "EF2C63AB",
              "invoice_settings": {
                "custom_fields": null,
                "default_payment_method": null,
                "footer": null
              },
              "livemode": false,
              "metadata": {
                "calsync_api_version": "5a9da492108f35fdcdd63c996f6e427abe01e623",
                "calsync_user_id": "29"
              },
              "name": null,
              "next_invoice_sequence": 1,
              "phone": null,
              "preferred_locales": [
              ],
              "shipping": null,
              "sources": {
                "object": "list",
                "data": [
                ],
                "has_more": false,
                "total_count": 0,
                "url": "/v1/customers/cus_FkAZ6RUnwxx45g/sources"
              },
              "subscriptions": {
                "object": "list",
                "data": [
                ],
                "has_more": false,
                "total_count": 0,
                "url": "/v1/customers/cus_FkAZ6RUnwxx45g/subscriptions"
              },
              "tax_exempt": "none",
              "tax_ids": {
                "object": "list",
                "data": [
                ],
                "has_more": false,
                "total_count": 0,
                "url": "/v1/customers/cus_FkAZ6RUnwxx45g/tax_ids"
              },
              "tax_info": null,
              "tax_info_verification": null
            },
            {
              "id": "cus_FkAZHeCbmZLlzI",
              "object": "customer",
              "account_balance": 0,
              "address": null,
              "balance": 0,
              "created": 1567533325,
              "currency": null,
              "default_source": "card_1FEgDwFFYxHXGyKxHtvaByNc",
              "delinquent": false,
              "description": "Test User",
              "discount": null,
              "email": "ian.raynor@sipes.io",
              "invoice_prefix": "90EB1EC7",
              "invoice_settings": {
                "custom_fields": null,
                "default_payment_method": null,
                "footer": null
              },
              "livemode": false,
              "metadata": {
                "calsync_api_version": "5a9da492108f35fdcdd63c996f6e427abe01e623",
                "calsync_user_id": "33"
              },
              "name": null,
              "next_invoice_sequence": 1,
              "phone": null,
              "preferred_locales": [
              ],
              "shipping": null,
              "sources": {
                "object": "list",
                "data": [
                  {
                    "id": "card_1FEgDwFFYxHXGyKxHtvaByNc",
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
                    "customer": "cus_FkAZHeCbmZLlzI",
                    "cvc_check": "pass",
                    "dynamic_last4": null,
                    "exp_month": 6,
                    "exp_year": 2022,
                    "fingerprint": "t6Eo2YGsl3ZPivuR",
                    "funding": "credit",
                    "last4": "4242",
                    "metadata": {
                    },
                    "name": null,
                    "tokenization_method": null
                  }
                ],
                "has_more": false,
                "total_count": 1,
                "url": "/v1/customers/cus_FkAZHeCbmZLlzI/sources"
              },
              "subscriptions": {
                "object": "list",
                "data": [
                ],
                "has_more": false,
                "total_count": 0,
                "url": "/v1/customers/cus_FkAZHeCbmZLlzI/subscriptions"
              },
              "tax_exempt": "none",
              "tax_ids": {
                "object": "list",
                "data": [
                ],
                "has_more": false,
                "total_count": 0,
                "url": "/v1/customers/cus_FkAZHeCbmZLlzI/tax_ids"
              },
              "tax_info": null,
              "tax_info_verification": null
            },
            {
              "id": "cus_FzVeTzX65rCx3X",
              "object": "customer",
              "account_balance": 0,
              "address": null,
              "balance": 0,
              "created": 1571071390,
              "currency": null,
              "default_source": null,
              "delinquent": false,
              "description": "Test User",
              "discount": null,
              "email": "dwana.wehner@zemlak.net",
              "invoice_prefix": "DA1CC780",
              "invoice_settings": {
                "custom_fields": null,
                "default_payment_method": null,
                "footer": null
              },
              "livemode": false,
              "metadata": {
                "calsync_api_version": "248b9ec2b5aae5aeca41ab86698e92dea81b1e64",
                "calsync_user_id": "54"
              },
              "name": null,
              "next_invoice_sequence": 1,
              "phone": null,
              "preferred_locales": [
              ],
              "shipping": null,
              "sources": {
                "object": "list",
                "data": [
                ],
                "has_more": false,
                "total_count": 0,
                "url": "/v1/customers/cus_FzVeTzX65rCx3X/sources"
              },
              "subscriptions": {
                "object": "list",
                "data": [
                ],
                "has_more": false,
                "total_count": 0,
                "url": "/v1/customers/cus_FzVeTzX65rCx3X/subscriptions"
              },
              "tax_exempt": "none",
              "tax_ids": {
                "object": "list",
                "data": [
                ],
                "has_more": false,
                "total_count": 0,
                "url": "/v1/customers/cus_FzVeTzX65rCx3X/tax_ids"
              },
              "tax_info": null,
              "tax_info_verification": null
            }

          ],
          "has_more": true,
          "url": "/v1/customers"
        }
      R
    end
    let(:page2_response) do
      <<~R
        {
          "object": "list",
          "data": [
            {
              "id": "cus_FzW3jwRbjcf2tB",
              "object": "customer",
              "account_balance": 0,
              "address": null,
              "balance": 0,
              "created": 1571072853,
              "currency": null,
              "default_source": "card_1FTX17FFYxHXGyKxGBagJuui",
              "delinquent": false,
              "description": "Test User",
              "discount": null,
              "email": "marshall@mraz.net",
              "invoice_prefix": "D088C0C5",
              "invoice_settings": {
                "custom_fields": null,
                "default_payment_method": null,
                "footer": null
              },
              "livemode": false,
              "metadata": {
                "calsync_api_version": "6bc3900c1e0ba7584d2e75379ae6934ddafd86ad",
                "calsync_user_id": "67"
              },
              "name": null,
              "next_invoice_sequence": 1,
              "phone": null,
              "preferred_locales": [
              ],
              "shipping": null,
              "sources": {
                "object": "list",
                "data": [
                  {
                    "id": "card_1FTX17FFYxHXGyKxGBagJuui",
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
                    "customer": "cus_FzW3jwRbjcf2tB",
                    "cvc_check": "pass",
                    "dynamic_last4": null,
                    "exp_month": 6,
                    "exp_year": 2022,
                    "fingerprint": "t6Eo2YGsl3ZPivuR",
                    "funding": "credit",
                    "last4": "4242",
                    "metadata": {
                    },
                    "name": null,
                    "tokenization_method": null
                  },
                  {
                    "id": "card_1FTX18FFYxHXGyKxdwZK7Z9o",
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
                    "customer": "cus_FzW3jwRbjcf2tB",
                    "cvc_check": "pass",
                    "dynamic_last4": null,
                    "exp_month": 6,
                    "exp_year": 2022,
                    "fingerprint": "t6Eo2YGsl3ZPivuR",
                    "funding": "credit",
                    "last4": "4242",
                    "metadata": {
                    },
                    "name": null,
                    "tokenization_method": null
                  }
                ],
                "has_more": false,
                "total_count": 2,
                "url": "/v1/customers/cus_FzW3jwRbjcf2tB/sources"
              },
              "subscriptions": {
                "object": "list",
                "data": [
                ],
                "has_more": false,
                "total_count": 0,
                "url": "/v1/customers/cus_FzW3jwRbjcf2tB/subscriptions"
              },
              "tax_exempt": "none",
              "tax_ids": {
                "object": "list",
                "data": [
                ],
                "has_more": false,
                "total_count": 0,
                "url": "/v1/customers/cus_FzW3jwRbjcf2tB/tax_ids"
              },
              "tax_info": null,
              "tax_info_verification": null
            },
            {
              "id": "cus_FzWECr4KA28Zv2",
              "object": "customer",
              "account_balance": 0,
              "address": null,
              "balance": 0,
              "created": 1571073549,
              "currency": null,
              "default_source": "src_1IkvK0FFYxHXGyKxJ4YQADLJ",
              "delinquent": false,
              "description": "Test User",
              "discount": null,
              "email": "thomasina@mclaughlinconsidine.net",
              "invoice_prefix": "6CE5ACB5",
              "invoice_settings": {
                "custom_fields": null,
                "default_payment_method": null,
                "footer": null
              },
              "livemode": false,
              "metadata": {
                "calsync_api_version": "unknown-version",
                "calsync_user_id": "2"
              },
              "name": null,
              "next_invoice_sequence": 1,
              "phone": null,
              "preferred_locales": [
              ],
              "shipping": null,
              "sources": {
                "object": "list",
                "data": [
                  {
                    "id": "src_1IkvK0FFYxHXGyKxJ4YQADLJ",
                    "object": "source",
                    "amount": null,
                    "card": {
                      "exp_month": 1,
                      "exp_year": 2029,
                      "last4": "4242",
                      "country": "US",
                      "brand": "Visa",
                      "cvc_check": "pass",
                      "funding": "credit",
                      "fingerprint": "t6Eo2YGsl3ZPivuR",
                      "three_d_secure": "optional",
                      "name": null,
                      "address_line1_check": null,
                      "address_zip_check": null,
                      "tokenization_method": null,
                      "dynamic_last4": null
                    },
                    "client_secret": "src_client_secret_BD0MoEKU6hMRQANrKHfBfCfG",
                    "created": 1619546864,
                    "currency": null,
                    "customer": "cus_FzWECr4KA28Zv2",
                    "flow": "none",
                    "livemode": false,
                    "metadata": {
                    },
                    "owner": {
                      "address": null,
                      "email": null,
                      "name": null,
                      "phone": null,
                      "verified_address": null,
                      "verified_email": null,
                      "verified_name": null,
                      "verified_phone": null
                    },
                    "statement_descriptor": null,
                    "status": "chargeable",
                    "type": "card",
                    "usage": "reusable"
                  }
                ],
                "has_more": false,
                "total_count": 1,
                "url": "/v1/customers/cus_FzWECr4KA28Zv2/sources"
              },
              "subscriptions": {
                "object": "list",
                "data": [
                ],
                "has_more": false,
                "total_count": 0,
                "url": "/v1/customers/cus_FzWECr4KA28Zv2/subscriptions"
              },
              "tax_exempt": "none",
              "tax_ids": {
                "object": "list",
                "data": [
                ],
                "has_more": false,
                "total_count": 0,
                "url": "/v1/customers/cus_FzWECr4KA28Zv2/tax_ids"
              },
              "tax_info": null,
              "tax_info_verification": null
            },
            {
              "id": "cus_FzWEzhD0LLNVbe",
              "object": "customer",
              "account_balance": 0,
              "address": null,
              "balance": 0,
              "created": 1571073550,
              "currency": null,
              "default_source": "card_1FTXCMFFYxHXGyKxTUB07Lr4",
              "delinquent": false,
              "description": "Test User",
              "discount": null,
              "email": "glen_kirlin@paucek.name",
              "invoice_prefix": "C8DF0020",
              "invoice_settings": {
                "custom_fields": null,
                "default_payment_method": null,
                "footer": null
              },
              "livemode": false,
              "metadata": {
                "calsync_api_version": "unknown-version",
                "calsync_user_id": "8"
              },
              "name": null,
              "next_invoice_sequence": 1,
              "phone": null,
              "preferred_locales": [
              ],
              "shipping": null,
              "sources": {
                "object": "list",
                "data": [
                  {
                    "id": "card_1FTXCMFFYxHXGyKxTUB07Lr4",
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
                    "customer": "cus_FzWEzhD0LLNVbe",
                    "cvc_check": "pass",
                    "dynamic_last4": null,
                    "exp_month": 6,
                    "exp_year": 2022,
                    "fingerprint": "t6Eo2YGsl3ZPivuR",
                    "funding": "credit",
                    "last4": "4242",
                    "metadata": {
                    },
                    "name": null,
                    "tokenization_method": null
                  }
                ],
                "has_more": false,
                "total_count": 1,
                "url": "/v1/customers/cus_FzWEzhD0LLNVbe/sources"
              },
              "subscriptions": {
                "object": "list",
                "data": [
                ],
                "has_more": false,
                "total_count": 0,
                "url": "/v1/customers/cus_FzWEzhD0LLNVbe/subscriptions"
              },
              "tax_exempt": "none",
              "tax_ids": {
                "object": "list",
                "data": [
                ],
                "has_more": false,
                "total_count": 0,
                "url": "/v1/customers/cus_FzWEzhD0LLNVbe/tax_ids"
              },
              "tax_info": null,
              "tax_info_verification": null
            }
          ],
          "has_more": true,
          "url": "/v1/customers"
        }
      R
    end
    let(:page3_response) do
      <<~R
        {
          "object": "list",
          "data": [],
          "has_more": false,
          "url": "/v1/customers"
        }
      R
    end
    let(:expected_items_count) { 6 }
    def stub_service_requests
      return [
        stub_request(:get, "https://api.stripe.com/v1/customers").
            with(headers: {"Authorization" => "Basic YmZrZXk6"}).
            to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://api.stripe.com/v1/customers?starting_after=cus_FzVeTzX65rCx3X").
            to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://api.stripe.com/v1/customers?starting_after=cus_FzWEzhD0LLNVbe").
            to_return(status: 200, body: page3_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.stripe.com/v1/customers").
          to_return(status: 503, body: "uhh")
    end
  end
  describe "webhook validation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "stripe_customer_v1") }
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
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "stripe_customer_v1") }
    let(:svc) { Webhookdb::Services.service_instance(sint) }

    describe "calculate_create_state_machine" do
      it "asks for webhook secret" do
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: "Paste or type your secret here:",
          prompt_is_secret: true,
          post_to_url: end_with("/service_integrations/#{sint.opaque_id}/transition/webhook_secret"),
          complete: false,
          output: match("We've made an endpoint available for Stripe Customer webhooks:"),
        )
      end

      it "confirms reciept of webhook secret, returns org database info" do
        sint.webhook_secret = "whsec_abcasdf"
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          prompt: "",
          prompt_is_secret: false,
          post_to_url: "",
          complete: true,
          output: match("Great! WebhookDB is now listening for Stripe Customer webhooks."),
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
            "url": "/v1/customers"
          }
        R
      end

      def stub_service_request
        return stub_request(:get, "https://api.stripe.com/v1/customers").
            with(headers: {"Authorization" => "Basic d2hzZWNfYWJjYXNkZjo="}).
            to_return(status: 200, body: success_body, headers: {})
      end
      it "asks for backfill key" do
        sm = sint.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: "Paste or type your Restricted Key here:",
          prompt_is_secret: true,
          post_to_url: end_with("/service_integrations/#{sint.opaque_id}/transition/backfill_key"),
          complete: false,
          output: match("In order to backfill Stripe Customers, we need an API key."),
        )
      end

      it "confirms reciept of backfill key, returns org database info" do
        sint.backfill_key = "whsec_abcasdf"
        res = stub_service_request
        sm = sint.calculate_backfill_state_machine
        expect(res).to have_been_made
        expect(sm).to have_attributes(
          needs_input: false,
          prompt: "",
          prompt_is_secret: false,
          post_to_url: "",
          complete: true,
          output: match("Great! We are going to start backfilling your Stripe Customers."),
        )
      end
    end
  end
end
