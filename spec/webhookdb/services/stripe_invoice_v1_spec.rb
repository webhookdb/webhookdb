# frozen_string_literal: true

require "support/shared_examples_for_services"

RSpec.describe Webhookdb::Services::StripeInvoiceV1, :db do
  it_behaves_like "a service implementation", "stripe_invoice_v1" do
    let(:body) do
      JSON.parse(<<~J)
        {
          "id": "evt_1CiPtv2eZvKYlo2CcUZsDcO6",
          "object": "event",
          "api_version": "2018-05-21",
          "created": 1530291411,
          "data": {
            "object": {
              "id": "in_1KeQYU2eZvKYlo2CIgl90FWy",
              "object": "invoice",
              "account_country": "US",
              "account_name": "Stripe.com",
              "account_tax_ids": null,
              "amount_due": 10000,
              "amount_paid": 0,
              "amount_remaining": 10000,
              "application_fee_amount": null,
              "attempt_count": 0,
              "attempted": false,
              "auto_advance": true,
              "automatic_tax": {
                "enabled": false,
                "status": null
              },
              "billing_reason": "manual",
              "charge": null,
              "collection_method": "charge_automatically",
              "created": 1647551302,
              "currency": "usd",
              "custom_fields": null,
              "customer": "cus_LL6mM3Wpihv4os",
              "customer_address": null,
              "customer_email": "jayne_cassin@example.com",
              "customer_name": null,
              "customer_phone": null,
              "customer_shipping": null,
              "customer_tax_exempt": "none",
              "customer_tax_ids": [],
              "default_payment_method": null,
              "default_source": null,
              "default_tax_rates": [],
              "description": null,
              "discount": null,
              "discounts": [],
              "due_date": null,
              "ending_balance": null,
              "footer": null,
              "hosted_invoice_url": null,
              "invoice_pdf": null,
              "last_finalization_error": null,
              "lines": {
                "object": "list",
                "data": [
                  {
                    "id": "il_1KeQYU2eZvKYlo2CJeXl4hu7",
                    "object": "line_item",
                    "amount": 10000,
                    "currency": "usd",
                    "description": "My First Invoice Item (created for API docs)",
                    "discount_amounts": [],
                    "discountable": true,
                    "discounts": [],
                    "invoice_item": "ii_1KeQYU2eZvKYlo2CPo9dZfkO",
                    "livemode": false,
                    "metadata": {},
                    "period": {
                      "end": 1647551302,
                      "start": 1647551302
                    },
                    "price": {
                      "id": "price_1KeNVd2eZvKYlo2Cw3Ur2S4q",
                      "object": "price",
                      "active": true,
                      "billing_scheme": "per_unit",
                      "created": 1647539593,
                      "currency": "usd",
                      "livemode": false,
                      "lookup_key": null,
                      "metadata": {},
                      "nickname": null,
                      "product": "prod_LL3chB5YcjaLlR",
                      "recurring": null,
                      "tax_behavior": "unspecified",
                      "tiers_mode": null,
                      "transform_quantity": null,
                      "type": "one_time",
                      "unit_amount": 10000,
                      "unit_amount_decimal": "10000"
                    },
                    "proration": false,
                    "proration_details": {
                      "credited_items": null
                    },
                    "quantity": 1,
                    "subscription": null,
                    "tax_amounts": [],
                    "tax_rates": [],
                    "type": "invoiceitem"
                  }
                ],
                "has_more": false,
                "url": "/v1/invoices/in_1KeQYU2eZvKYlo2CIgl90FWy/lines"
              },
              "livemode": false,
              "metadata": {},
              "next_payment_attempt": 1647554902,
              "number": "8EB2541-DRAFT",
              "on_behalf_of": null,
              "paid": false,
              "paid_out_of_band": false,
              "payment_intent": null,
              "payment_settings": {
                "payment_method_options": null,
                "payment_method_types": null
              },
              "period_end": 1647551302,
              "period_start": 1647551302,
              "post_payment_credit_notes_amount": 0,
              "pre_payment_credit_notes_amount": 0,
              "quote": null,
              "receipt_number": null,
              "starting_balance": 0,
              "statement_descriptor": null,
              "status": "draft",
              "status_transitions": {
                "finalized_at": null,
                "marked_uncollectible_at": null,
                "paid_at": null,
                "voided_at": null
              },
              "subscription": null,
              "subtotal": 10000,
              "tax": null,
              "test_clock": null,
              "total": 10000,
              "total_discount_amounts": [],
              "total_tax_amounts": [],
              "transfer_data": null,
              "webhooks_delivered_at": null
            }
          },
          "livemode": false,
          "pending_webhooks": 0,
          "request": {
            "id": null,
            "idempotency_key": null
          },
          "type": "not sure"
        }
      J
    end
    let(:expected_data) { body["data"]["object"] }
  end
  it_behaves_like "a service implementation that prevents overwriting new data with old", "stripe_invoice_v1" do
    let(:old_body) do
      JSON.parse(<<~J)
        {
          "id": "evt_1CiPtv2eZvKYlo2CcUZsDcO6",
          "object": "event",
          "api_version": "2018-05-21",
          "created": 1530291412,
          "data": {
            "object": {
              "id": "in_1KeQYU2eZvKYlo2CIgl10FWy",
              "object": "invoice",
              "account_country": "US",
              "account_name": "Stripe.com",
              "account_tax_ids": null,
              "amount_due": 10000,
              "amount_paid": 0,
              "amount_remaining": 10000,
              "application_fee_amount": null,
              "attempt_count": 0,
              "attempted": false,
              "auto_advance": true,
              "automatic_tax": {
                "enabled": false,
                "status": null
              },
              "billing_reason": "manual",
              "charge": null,
              "collection_method": "charge_automatically",
              "created": 1647551302,
              "currency": "usd",
              "custom_fields": null,
              "customer": "cus_LL6mM3Wpihv4os",
              "customer_address": null,
              "customer_email": "jayne_cassin@example.com",
              "customer_name": null,
              "customer_phone": null,
              "customer_shipping": null,
              "customer_tax_exempt": "none",
              "customer_tax_ids": [],
              "default_payment_method": null,
              "default_source": null,
              "default_tax_rates": [],
              "description": null,
              "discount": null,
              "discounts": [],
              "due_date": null,
              "ending_balance": null,
              "footer": null,
              "hosted_invoice_url": null,
              "invoice_pdf": null,
              "last_finalization_error": null,
              "lines": {
                "object": "list",
                "data": [
                  {
                    "id": "il_1KeQYU2eZvKYlo2CJeXl4hu7",
                    "object": "line_item",
                    "amount": 10000,
                    "currency": "usd",
                    "description": "My First Invoice Item (created for API docs)",
                    "discount_amounts": [],
                    "discountable": true,
                    "discounts": [],
                    "invoice_item": "ii_1KeQYU2eZvKYlo2CPo9dZfkO",
                    "livemode": false,
                    "metadata": {},
                    "period": {
                      "end": 1647551302,
                      "start": 1647551302
                    },
                    "price": {
                      "id": "price_1KeNVd2eZvKYlo2Cw3Ur2S4q",
                      "object": "price",
                      "active": true,
                      "billing_scheme": "per_unit",
                      "created": 1647539593,
                      "currency": "usd",
                      "livemode": false,
                      "lookup_key": null,
                      "metadata": {},
                      "nickname": null,
                      "product": "prod_LL3chB5YcjaLlR",
                      "recurring": null,
                      "tax_behavior": "unspecified",
                      "tiers_mode": null,
                      "transform_quantity": null,
                      "type": "one_time",
                      "unit_amount": 10000,
                      "unit_amount_decimal": "10000"
                    },
                    "proration": false,
                    "proration_details": {
                      "credited_items": null
                    },
                    "quantity": 1,
                    "subscription": null,
                    "tax_amounts": [],
                    "tax_rates": [],
                    "type": "invoiceitem"
                  }
                ],
                "has_more": false,
                "url": "/v1/invoices/in_1KeQYU2eZvKYlo2CIgl90FWy/lines"
              },
              "livemode": false,
              "metadata": {},
              "next_payment_attempt": 1647554902,
              "number": "8EB2541-DRAFT",
              "on_behalf_of": null,
              "paid": false,
              "paid_out_of_band": false,
              "payment_intent": null,
              "payment_settings": {
                "payment_method_options": null,
                "payment_method_types": null
              },
              "period_end": 1647551302,
              "period_start": 1647551302,
              "post_payment_credit_notes_amount": 0,
              "pre_payment_credit_notes_amount": 0,
              "quote": null,
              "receipt_number": null,
              "starting_balance": 0,
              "statement_descriptor": null,
              "status": "draft",
              "status_transitions": {
                "finalized_at": null,
                "marked_uncollectible_at": null,
                "paid_at": null,
                "voided_at": null
              },
              "subscription": null,
              "subtotal": 10000,
              "tax": null,
              "test_clock": null,
              "total": 10000,
              "total_discount_amounts": [],
              "total_tax_amounts": [],
              "transfer_data": null,
              "webhooks_delivered_at": null
            }
          },
          "livemode": false,
          "pending_webhooks": 0,
          "request": {
            "id": null,
            "idempotency_key": null
          },
          "type": "not sure"
        }
      J
    end

    let(:new_body) do
      JSON.parse(<<~J)
        {
          "id": "evt_1CiPtv2eZvKYlo2CcUZsDcO6",
          "object": "event",
          "api_version": "2018-05-21",
          "created": 1530291413,
          "data": {
            "object": {
              "id": "in_1KeQYU2eZvKYlo2CIgl10FWy",
              "object": "invoice",
              "account_country": "US",
              "account_name": "Stripe.com",
              "account_tax_ids": null,
              "amount_due": 10000,
              "amount_paid": 0,
              "amount_remaining": 10000,
              "application_fee_amount": null,
              "attempt_count": 0,
              "attempted": false,
              "auto_advance": true,
              "automatic_tax": {
                "enabled": false,
                "status": null
              },
              "billing_reason": "manual",
              "charge": null,
              "collection_method": "charge_automatically",
              "created": 1647551302,
              "currency": "usd",
              "custom_fields": null,
              "customer": "cus_LL6mM3Wpihv4os",
              "customer_address": null,
              "customer_email": "jayne_cassin@example.com",
              "customer_name": null,
              "customer_phone": null,
              "customer_shipping": null,
              "customer_tax_exempt": "none",
              "customer_tax_ids": [],
              "default_payment_method": null,
              "default_source": null,
              "default_tax_rates": [],
              "description": null,
              "discount": null,
              "discounts": [],
              "due_date": null,
              "ending_balance": null,
              "footer": null,
              "hosted_invoice_url": null,
              "invoice_pdf": null,
              "last_finalization_error": null,
              "lines": {
                "object": "list",
                "data": [
                  {
                    "id": "il_1KeQYU2eZvKYlo2CJeXl4hu7",
                    "object": "line_item",
                    "amount": 10000,
                    "currency": "usd",
                    "description": "My First Invoice Item (created for API docs)",
                    "discount_amounts": [],
                    "discountable": true,
                    "discounts": [],
                    "invoice_item": "ii_1KeQYU2eZvKYlo2CPo9dZfkO",
                    "livemode": false,
                    "metadata": {},
                    "period": {
                      "end": 1647551302,
                      "start": 1647551302
                    },
                    "price": {
                      "id": "price_1KeNVd2eZvKYlo2Cw3Ur2S4q",
                      "object": "price",
                      "active": true,
                      "billing_scheme": "per_unit",
                      "created": 1647539593,
                      "currency": "usd",
                      "livemode": false,
                      "lookup_key": null,
                      "metadata": {},
                      "nickname": null,
                      "product": "prod_LL3chB5YcjaLlR",
                      "recurring": null,
                      "tax_behavior": "unspecified",
                      "tiers_mode": null,
                      "transform_quantity": null,
                      "type": "one_time",
                      "unit_amount": 10000,
                      "unit_amount_decimal": "10000"
                    },
                    "proration": false,
                    "proration_details": {
                      "credited_items": null
                    },
                    "quantity": 1,
                    "subscription": null,
                    "tax_amounts": [],
                    "tax_rates": [],
                    "type": "invoiceitem"
                  }
                ],
                "has_more": false,
                "url": "/v1/invoices/in_1KeQYU2eZvKYlo2CIgl90FWy/lines"
              },
              "livemode": false,
              "metadata": {},
              "next_payment_attempt": 1647554902,
              "number": "8EB2541-DRAFT",
              "on_behalf_of": null,
              "paid": false,
              "paid_out_of_band": false,
              "payment_intent": null,
              "payment_settings": {
                "payment_method_options": null,
                "payment_method_types": null
              },
              "period_end": 1647551302,
              "period_start": 1647551302,
              "post_payment_credit_notes_amount": 0,
              "pre_payment_credit_notes_amount": 0,
              "quote": null,
              "receipt_number": null,
              "starting_balance": 0,
              "statement_descriptor": null,
              "status": "draft",
              "status_transitions": {
                "finalized_at": null,
                "marked_uncollectible_at": null,
                "paid_at": null,
                "voided_at": null
              },
              "subscription": null,
              "subtotal": 10000,
              "tax": null,
              "test_clock": null,
              "total": 10000,
              "total_discount_amounts": [],
              "total_tax_amounts": [],
              "transfer_data": null,
              "webhooks_delivered_at": null
            }
          },
          "livemode": false,
          "pending_webhooks": 0,
          "request": {
            "id": null,
            "idempotency_key": null
          },
          "type": "not sure"
        }
      J
    end
    let(:expected_old_data) { old_body["data"]["object"] }
    let(:expected_new_data) { new_body["data"]["object"] }
  end
  it_behaves_like "a service implementation that verifies backfill secrets" do
    let(:correct_creds_sint) do
      Webhookdb::Fixtures.service_integration.create(
        service_name: "stripe_invoice_v1",
        backfill_key: "bfkey",
      )
    end
    let(:incorrect_creds_sint) do
      Webhookdb::Fixtures.service_integration.create(
        service_name: "stripe_invoice_v1",
        backfill_key: "bfkey_wrong",
      )
    end

    let(:success_body) do
      <<~R
        {
          "object": "list",
          "data": [],
          "has_more": false,
          "url": "/v1/invoices"
        }
      R
    end
    def stub_service_request
      return stub_request(:get, "https://api.stripe.com/v1/invoices").
          with(headers: {"Authorization" => "Basic YmZrZXk6"}).
          to_return(status: 200, body: success_body, headers: {})
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.stripe.com/v1/invoices").
          with(headers: {"Authorization" => "Basic YmZrZXlfd3Jvbmc6"}).
          to_return(status: 403, body: "", headers: {})
    end
  end
  it_behaves_like "a service implementation that can backfill", "stripe_invoice_v1" do
    let(:page1_response) do
      <<~R
        {
          "object": "list",
          "data": [
            {
              "id": "in_1KeQYU2eZvKYlo2CIgl10FWy",
              "object": "invoice",
              "account_country": "US",
              "account_name": "Stripe.com",
              "account_tax_ids": null,
              "amount_due": 10000,
              "amount_paid": 0,
              "amount_remaining": 10000,
              "application_fee_amount": null,
              "attempt_count": 0,
              "attempted": false,
              "auto_advance": true,
              "automatic_tax": {
                "enabled": false,
                "status": null
              },
              "billing_reason": "manual",
              "charge": null,
              "collection_method": "charge_automatically",
              "created": 1647551302,
              "currency": "usd",
              "custom_fields": null,
              "customer": "cus_LL6mM3Wpihv4os",
              "customer_address": null,
              "customer_email": "jayne_cassin@example.com",
              "customer_name": null,
              "customer_phone": null,
              "customer_shipping": null,
              "customer_tax_exempt": "none",
              "customer_tax_ids": [],
              "default_payment_method": null,
              "default_source": null,
              "default_tax_rates": [],
              "description": null,
              "discount": null,
              "discounts": [],
              "due_date": null,
              "ending_balance": null,
              "footer": null,
              "hosted_invoice_url": null,
              "invoice_pdf": null,
              "last_finalization_error": null,
              "lines": {
                "object": "list",
                "data": [
                  {
                    "id": "il_1KeQYU2eZvKYlo2CJeXl4hu7",
                    "object": "line_item",
                    "amount": 10000,
                    "currency": "usd",
                    "description": "My First Invoice Item (created for API docs)",
                    "discount_amounts": [],
                    "discountable": true,
                    "discounts": [],
                    "invoice_item": "ii_1KeQYU2eZvKYlo2CPo9dZfkO",
                    "livemode": false,
                    "metadata": {},
                    "period": {
                      "end": 1647551302,
                      "start": 1647551302
                    },
                    "price": {
                      "id": "price_1KeNVd2eZvKYlo2Cw3Ur2S4q",
                      "object": "price",
                      "active": true,
                      "billing_scheme": "per_unit",
                      "created": 1647539593,
                      "currency": "usd",
                      "livemode": false,
                      "lookup_key": null,
                      "metadata": {},
                      "nickname": null,
                      "product": "prod_LL3chB5YcjaLlR",
                      "recurring": null,
                      "tax_behavior": "unspecified",
                      "tiers_mode": null,
                      "transform_quantity": null,
                      "type": "one_time",
                      "unit_amount": 10000,
                      "unit_amount_decimal": "10000"
                    },
                    "proration": false,
                    "proration_details": {
                      "credited_items": null
                    },
                    "quantity": 1,
                    "subscription": null,
                    "tax_amounts": [],
                    "tax_rates": [],
                    "type": "invoiceitem"
                  }
                ],
                "has_more": false,
                "url": "/v1/invoices/in_1KeQYU2eZvKYlo2CIgl90FWy/lines"
              },
              "livemode": false,
              "metadata": {},
              "next_payment_attempt": 1647554902,
              "number": "8EB2541-DRAFT",
              "on_behalf_of": null,
              "paid": false,
              "paid_out_of_band": false,
              "payment_intent": null,
              "payment_settings": {
                "payment_method_options": null,
                "payment_method_types": null
              },
              "period_end": 1647551302,
              "period_start": 1647551302,
              "post_payment_credit_notes_amount": 0,
              "pre_payment_credit_notes_amount": 0,
              "quote": null,
              "receipt_number": null,
              "starting_balance": 0,
              "statement_descriptor": null,
              "status": "draft",
              "status_transitions": {
                "finalized_at": null,
                "marked_uncollectible_at": null,
                "paid_at": null,
                "voided_at": null
              },
              "subscription": null,
              "subtotal": 10000,
              "tax": null,
              "test_clock": null,
              "total": 10000,
              "total_discount_amounts": [],
              "total_tax_amounts": [],
              "transfer_data": null,
              "webhooks_delivered_at": null
            },
            {
              "id": "in_1KeQYU2eZvKYlo2CIgl20FWy",
              "object": "invoice",
              "account_country": "US",
              "account_name": "Stripe.com",
              "account_tax_ids": null,
              "amount_due": 10000,
              "amount_paid": 0,
              "amount_remaining": 10000,
              "application_fee_amount": null,
              "attempt_count": 0,
              "attempted": false,
              "auto_advance": true,
              "automatic_tax": {
                "enabled": false,
                "status": null
              },
              "billing_reason": "manual",
              "charge": null,
              "collection_method": "charge_automatically",
              "created": 1647551302,
              "currency": "usd",
              "custom_fields": null,
              "customer": "cus_LL6mM3Wpihv4os",
              "customer_address": null,
              "customer_email": "jayne_cassin@example.com",
              "customer_name": null,
              "customer_phone": null,
              "customer_shipping": null,
              "customer_tax_exempt": "none",
              "customer_tax_ids": [],
              "default_payment_method": null,
              "default_source": null,
              "default_tax_rates": [],
              "description": null,
              "discount": null,
              "discounts": [],
              "due_date": null,
              "ending_balance": null,
              "footer": null,
              "hosted_invoice_url": null,
              "invoice_pdf": null,
              "last_finalization_error": null,
              "lines": {
                "object": "list",
                "data": [
                  {
                    "id": "il_1KeQYU2eZvKYlo2CJeXl4hu7",
                    "object": "line_item",
                    "amount": 10000,
                    "currency": "usd",
                    "description": "My First Invoice Item (created for API docs)",
                    "discount_amounts": [],
                    "discountable": true,
                    "discounts": [],
                    "invoice_item": "ii_1KeQYU2eZvKYlo2CPo9dZfkO",
                    "livemode": false,
                    "metadata": {},
                    "period": {
                      "end": 1647551302,
                      "start": 1647551302
                    },
                    "price": {
                      "id": "price_1KeNVd2eZvKYlo2Cw3Ur2S4q",
                      "object": "price",
                      "active": true,
                      "billing_scheme": "per_unit",
                      "created": 1647539593,
                      "currency": "usd",
                      "livemode": false,
                      "lookup_key": null,
                      "metadata": {},
                      "nickname": null,
                      "product": "prod_LL3chB5YcjaLlR",
                      "recurring": null,
                      "tax_behavior": "unspecified",
                      "tiers_mode": null,
                      "transform_quantity": null,
                      "type": "one_time",
                      "unit_amount": 10000,
                      "unit_amount_decimal": "10000"
                    },
                    "proration": false,
                    "proration_details": {
                      "credited_items": null
                    },
                    "quantity": 1,
                    "subscription": null,
                    "tax_amounts": [],
                    "tax_rates": [],
                    "type": "invoiceitem"
                  }
                ],
                "has_more": false,
                "url": "/v1/invoices/in_1KeQYU2eZvKYlo2CIgl90FWy/lines"
              },
              "livemode": false,
              "metadata": {},
              "next_payment_attempt": 1647554902,
              "number": "8EB2541-DRAFT",
              "on_behalf_of": null,
              "paid": false,
              "paid_out_of_band": false,
              "payment_intent": null,
              "payment_settings": {
                "payment_method_options": null,
                "payment_method_types": null
              },
              "period_end": 1647551302,
              "period_start": 1647551302,
              "post_payment_credit_notes_amount": 0,
              "pre_payment_credit_notes_amount": 0,
              "quote": null,
              "receipt_number": null,
              "starting_balance": 0,
              "statement_descriptor": null,
              "status": "draft",
              "status_transitions": {
                "finalized_at": null,
                "marked_uncollectible_at": null,
                "paid_at": null,
                "voided_at": null
              },
              "subscription": null,
              "subtotal": 10000,
              "tax": null,
              "test_clock": null,
              "total": 10000,
              "total_discount_amounts": [],
              "total_tax_amounts": [],
              "transfer_data": null,
              "webhooks_delivered_at": null
            },
            {
              "id": "in_1KeQYU2eZvKYlo2CIgl30FWy",
              "object": "invoice",
              "account_country": "US",
              "account_name": "Stripe.com",
              "account_tax_ids": null,
              "amount_due": 10000,
              "amount_paid": 0,
              "amount_remaining": 10000,
              "application_fee_amount": null,
              "attempt_count": 0,
              "attempted": false,
              "auto_advance": true,
              "automatic_tax": {
                "enabled": false,
                "status": null
              },
              "billing_reason": "manual",
              "charge": null,
              "collection_method": "charge_automatically",
              "created": 1647551302,
              "currency": "usd",
              "custom_fields": null,
              "customer": "cus_LL6mM3Wpihv4os",
              "customer_address": null,
              "customer_email": "jayne_cassin@example.com",
              "customer_name": null,
              "customer_phone": null,
              "customer_shipping": null,
              "customer_tax_exempt": "none",
              "customer_tax_ids": [],
              "default_payment_method": null,
              "default_source": null,
              "default_tax_rates": [],
              "description": null,
              "discount": null,
              "discounts": [],
              "due_date": null,
              "ending_balance": null,
              "footer": null,
              "hosted_invoice_url": null,
              "invoice_pdf": null,
              "last_finalization_error": null,
              "lines": {
                "object": "list",
                "data": [
                  {
                    "id": "il_1KeQYU2eZvKYlo2CJeXl4hu7",
                    "object": "line_item",
                    "amount": 10000,
                    "currency": "usd",
                    "description": "My First Invoice Item (created for API docs)",
                    "discount_amounts": [],
                    "discountable": true,
                    "discounts": [],
                    "invoice_item": "ii_1KeQYU2eZvKYlo2CPo9dZfkO",
                    "livemode": false,
                    "metadata": {},
                    "period": {
                      "end": 1647551302,
                      "start": 1647551302
                    },
                    "price": {
                      "id": "price_1KeNVd2eZvKYlo2Cw3Ur2S4q",
                      "object": "price",
                      "active": true,
                      "billing_scheme": "per_unit",
                      "created": 1647539593,
                      "currency": "usd",
                      "livemode": false,
                      "lookup_key": null,
                      "metadata": {},
                      "nickname": null,
                      "product": "prod_LL3chB5YcjaLlR",
                      "recurring": null,
                      "tax_behavior": "unspecified",
                      "tiers_mode": null,
                      "transform_quantity": null,
                      "type": "one_time",
                      "unit_amount": 10000,
                      "unit_amount_decimal": "10000"
                    },
                    "proration": false,
                    "proration_details": {
                      "credited_items": null
                    },
                    "quantity": 1,
                    "subscription": null,
                    "tax_amounts": [],
                    "tax_rates": [],
                    "type": "invoiceitem"
                  }
                ],
                "has_more": false,
                "url": "/v1/invoices/in_1KeQYU2eZvKYlo2CIgl90FWy/lines"
              },
              "livemode": false,
              "metadata": {},
              "next_payment_attempt": 1647554902,
              "number": "8EB2541-DRAFT",
              "on_behalf_of": null,
              "paid": false,
              "paid_out_of_band": false,
              "payment_intent": null,
              "payment_settings": {
                "payment_method_options": null,
                "payment_method_types": null
              },
              "period_end": 1647551302,
              "period_start": 1647551302,
              "post_payment_credit_notes_amount": 0,
              "pre_payment_credit_notes_amount": 0,
              "quote": null,
              "receipt_number": null,
              "starting_balance": 0,
              "statement_descriptor": null,
              "status": "draft",
              "status_transitions": {
                "finalized_at": null,
                "marked_uncollectible_at": null,
                "paid_at": null,
                "voided_at": null
              },
              "subscription": null,
              "subtotal": 10000,
              "tax": null,
              "test_clock": null,
              "total": 10000,
              "total_discount_amounts": [],
              "total_tax_amounts": [],
              "transfer_data": null,
              "webhooks_delivered_at": null
           }
          ],
          "has_more": true,
          "url": "/v1/invoices"
        }
      R
    end
    let(:page2_response) do
      <<~R
        {
          "object": "list",
          "data": [
            {
              "id": "in_1KeQYU2eZvKYlo2CIgl40FWy",
              "object": "invoice",
              "account_country": "US",
              "account_name": "Stripe.com",
              "account_tax_ids": null,
              "amount_due": 10000,
              "amount_paid": 0,
              "amount_remaining": 10000,
              "application_fee_amount": null,
              "attempt_count": 0,
              "attempted": false,
              "auto_advance": true,
              "automatic_tax": {
                "enabled": false,
                "status": null
              },
              "billing_reason": "manual",
              "charge": null,
              "collection_method": "charge_automatically",
              "created": 1647551302,
              "currency": "usd",
              "custom_fields": null,
              "customer": "cus_LL6mM3Wpihv4os",
              "customer_address": null,
              "customer_email": "jayne_cassin@example.com",
              "customer_name": null,
              "customer_phone": null,
              "customer_shipping": null,
              "customer_tax_exempt": "none",
              "customer_tax_ids": [],
              "default_payment_method": null,
              "default_source": null,
              "default_tax_rates": [],
              "description": null,
              "discount": null,
              "discounts": [],
              "due_date": null,
              "ending_balance": null,
              "footer": null,
              "hosted_invoice_url": null,
              "invoice_pdf": null,
              "last_finalization_error": null,
              "lines": {
                "object": "list",
                "data": [
                  {
                    "id": "il_1KeQYU2eZvKYlo2CJeXl4hu7",
                    "object": "line_item",
                    "amount": 10000,
                    "currency": "usd",
                    "description": "My First Invoice Item (created for API docs)",
                    "discount_amounts": [],
                    "discountable": true,
                    "discounts": [],
                    "invoice_item": "ii_1KeQYU2eZvKYlo2CPo9dZfkO",
                    "livemode": false,
                    "metadata": {},
                    "period": {
                      "end": 1647551302,
                      "start": 1647551302
                    },
                    "price": {
                      "id": "price_1KeNVd2eZvKYlo2Cw3Ur2S4q",
                      "object": "price",
                      "active": true,
                      "billing_scheme": "per_unit",
                      "created": 1647539593,
                      "currency": "usd",
                      "livemode": false,
                      "lookup_key": null,
                      "metadata": {},
                      "nickname": null,
                      "product": "prod_LL3chB5YcjaLlR",
                      "recurring": null,
                      "tax_behavior": "unspecified",
                      "tiers_mode": null,
                      "transform_quantity": null,
                      "type": "one_time",
                      "unit_amount": 10000,
                      "unit_amount_decimal": "10000"
                    },
                    "proration": false,
                    "proration_details": {
                      "credited_items": null
                    },
                    "quantity": 1,
                    "subscription": null,
                    "tax_amounts": [],
                    "tax_rates": [],
                    "type": "invoiceitem"
                  }
                ],
                "has_more": false,
                "url": "/v1/invoices/in_1KeQYU2eZvKYlo2CIgl90FWy/lines"
              },
              "livemode": false,
              "metadata": {},
              "next_payment_attempt": 1647554902,
              "number": "8EB2541-DRAFT",
              "on_behalf_of": null,
              "paid": false,
              "paid_out_of_band": false,
              "payment_intent": null,
              "payment_settings": {
                "payment_method_options": null,
                "payment_method_types": null
              },
              "period_end": 1647551302,
              "period_start": 1647551302,
              "post_payment_credit_notes_amount": 0,
              "pre_payment_credit_notes_amount": 0,
              "quote": null,
              "receipt_number": null,
              "starting_balance": 0,
              "statement_descriptor": null,
              "status": "draft",
              "status_transitions": {
                "finalized_at": null,
                "marked_uncollectible_at": null,
                "paid_at": null,
                "voided_at": null
              },
              "subscription": null,
              "subtotal": 10000,
              "tax": null,
              "test_clock": null,
              "total": 10000,
              "total_discount_amounts": [],
              "total_tax_amounts": [],
              "transfer_data": null,
              "webhooks_delivered_at": null
            },
            {
              "id": "in_1KeQYU2eZvKYlo2CIgl50FWy",
              "object": "invoice",
              "account_country": "US",
              "account_name": "Stripe.com",
              "account_tax_ids": null,
              "amount_due": 10000,
              "amount_paid": 0,
              "amount_remaining": 10000,
              "application_fee_amount": null,
              "attempt_count": 0,
              "attempted": false,
              "auto_advance": true,
              "automatic_tax": {
                "enabled": false,
                "status": null
              },
              "billing_reason": "manual",
              "charge": null,
              "collection_method": "charge_automatically",
              "created": 1647551302,
              "currency": "usd",
              "custom_fields": null,
              "customer": "cus_LL6mM3Wpihv4os",
              "customer_address": null,
              "customer_email": "jayne_cassin@example.com",
              "customer_name": null,
              "customer_phone": null,
              "customer_shipping": null,
              "customer_tax_exempt": "none",
              "customer_tax_ids": [],
              "default_payment_method": null,
              "default_source": null,
              "default_tax_rates": [],
              "description": null,
              "discount": null,
              "discounts": [],
              "due_date": null,
              "ending_balance": null,
              "footer": null,
              "hosted_invoice_url": null,
              "invoice_pdf": null,
              "last_finalization_error": null,
              "lines": {
                "object": "list",
                "data": [
                  {
                    "id": "il_1KeQYU2eZvKYlo2CJeXl4hu7",
                    "object": "line_item",
                    "amount": 10000,
                    "currency": "usd",
                    "description": "My First Invoice Item (created for API docs)",
                    "discount_amounts": [],
                    "discountable": true,
                    "discounts": [],
                    "invoice_item": "ii_1KeQYU2eZvKYlo2CPo9dZfkO",
                    "livemode": false,
                    "metadata": {},
                    "period": {
                      "end": 1647551302,
                      "start": 1647551302
                    },
                    "price": {
                      "id": "price_1KeNVd2eZvKYlo2Cw3Ur2S4q",
                      "object": "price",
                      "active": true,
                      "billing_scheme": "per_unit",
                      "created": 1647539593,
                      "currency": "usd",
                      "livemode": false,
                      "lookup_key": null,
                      "metadata": {},
                      "nickname": null,
                      "product": "prod_LL3chB5YcjaLlR",
                      "recurring": null,
                      "tax_behavior": "unspecified",
                      "tiers_mode": null,
                      "transform_quantity": null,
                      "type": "one_time",
                      "unit_amount": 10000,
                      "unit_amount_decimal": "10000"
                    },
                    "proration": false,
                    "proration_details": {
                      "credited_items": null
                    },
                    "quantity": 1,
                    "subscription": null,
                    "tax_amounts": [],
                    "tax_rates": [],
                    "type": "invoiceitem"
                  }
                ],
                "has_more": false,
                "url": "/v1/invoices/in_1KeQYU2eZvKYlo2CIgl90FWy/lines"
              },
              "livemode": false,
              "metadata": {},
              "next_payment_attempt": 1647554902,
              "number": "8EB2541-DRAFT",
              "on_behalf_of": null,
              "paid": false,
              "paid_out_of_band": false,
              "payment_intent": null,
              "payment_settings": {
                "payment_method_options": null,
                "payment_method_types": null
              },
              "period_end": 1647551302,
              "period_start": 1647551302,
              "post_payment_credit_notes_amount": 0,
              "pre_payment_credit_notes_amount": 0,
              "quote": null,
              "receipt_number": null,
              "starting_balance": 0,
              "statement_descriptor": null,
              "status": "draft",
              "status_transitions": {
                "finalized_at": null,
                "marked_uncollectible_at": null,
                "paid_at": null,
                "voided_at": null
              },
              "subscription": null,
              "subtotal": 10000,
              "tax": null,
              "test_clock": null,
              "total": 10000,
              "total_discount_amounts": [],
              "total_tax_amounts": [],
              "transfer_data": null,
              "webhooks_delivered_at": null
            },
            {
              "id": "in_1KeQYU2eZvKYlo2CIgl60FWy",
              "object": "invoice",
              "account_country": "US",
              "account_name": "Stripe.com",
              "account_tax_ids": null,
              "amount_due": 10000,
              "amount_paid": 0,
              "amount_remaining": 10000,
              "application_fee_amount": null,
              "attempt_count": 0,
              "attempted": false,
              "auto_advance": true,
              "automatic_tax": {
                "enabled": false,
                "status": null
              },
              "billing_reason": "manual",
              "charge": null,
              "collection_method": "charge_automatically",
              "created": 1647551302,
              "currency": "usd",
              "custom_fields": null,
              "customer": "cus_LL6mM3Wpihv4os",
              "customer_address": null,
              "customer_email": "jayne_cassin@example.com",
              "customer_name": null,
              "customer_phone": null,
              "customer_shipping": null,
              "customer_tax_exempt": "none",
              "customer_tax_ids": [],
              "default_payment_method": null,
              "default_source": null,
              "default_tax_rates": [],
              "description": null,
              "discount": null,
              "discounts": [],
              "due_date": null,
              "ending_balance": null,
              "footer": null,
              "hosted_invoice_url": null,
              "invoice_pdf": null,
              "last_finalization_error": null,
              "lines": {
                "object": "list",
                "data": [
                  {
                    "id": "il_1KeQYU2eZvKYlo2CJeXl4hu7",
                    "object": "line_item",
                    "amount": 10000,
                    "currency": "usd",
                    "description": "My First Invoice Item (created for API docs)",
                    "discount_amounts": [],
                    "discountable": true,
                    "discounts": [],
                    "invoice_item": "ii_1KeQYU2eZvKYlo2CPo9dZfkO",
                    "livemode": false,
                    "metadata": {},
                    "period": {
                      "end": 1647551302,
                      "start": 1647551302
                    },
                    "price": {
                      "id": "price_1KeNVd2eZvKYlo2Cw3Ur2S4q",
                      "object": "price",
                      "active": true,
                      "billing_scheme": "per_unit",
                      "created": 1647539593,
                      "currency": "usd",
                      "livemode": false,
                      "lookup_key": null,
                      "metadata": {},
                      "nickname": null,
                      "product": "prod_LL3chB5YcjaLlR",
                      "recurring": null,
                      "tax_behavior": "unspecified",
                      "tiers_mode": null,
                      "transform_quantity": null,
                      "type": "one_time",
                      "unit_amount": 10000,
                      "unit_amount_decimal": "10000"
                    },
                    "proration": false,
                    "proration_details": {
                      "credited_items": null
                    },
                    "quantity": 1,
                    "subscription": null,
                    "tax_amounts": [],
                    "tax_rates": [],
                    "type": "invoiceitem"
                  }
                ],
                "has_more": false,
                "url": "/v1/invoices/in_1KeQYU2eZvKYlo2CIgl90FWy/lines"
              },
              "livemode": false,
              "metadata": {},
              "next_payment_attempt": 1647554902,
              "number": "8EB2541-DRAFT",
              "on_behalf_of": null,
              "paid": false,
              "paid_out_of_band": false,
              "payment_intent": null,
              "payment_settings": {
                "payment_method_options": null,
                "payment_method_types": null
              },
              "period_end": 1647551302,
              "period_start": 1647551302,
              "post_payment_credit_notes_amount": 0,
              "pre_payment_credit_notes_amount": 0,
              "quote": null,
              "receipt_number": null,
              "starting_balance": 0,
              "statement_descriptor": null,
              "status": "draft",
              "status_transitions": {
                "finalized_at": null,
                "marked_uncollectible_at": null,
                "paid_at": null,
                "voided_at": null
              },
              "subscription": null,
              "subtotal": 10000,
              "tax": null,
              "test_clock": null,
              "total": 10000,
              "total_discount_amounts": [],
              "total_tax_amounts": [],
              "transfer_data": null,
              "webhooks_delivered_at": null
           }
          ],
          "has_more": true,
          "url": "/v1/invoices"
        }
      R
    end
    let(:page3_response) do
      <<~R
        {
          "object": "list",
          "data": [],
          "has_more": false,
          "url": "/v1/invoices"
        }
      R
    end
    let(:expected_items_count) { 6 }
    def stub_service_requests
      return [
        stub_request(:get, "https://api.stripe.com/v1/invoices").
            with(headers: {"Authorization" => "Basic YmZrZXk6"}).
            to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://api.stripe.com/v1/invoices?starting_after=in_1KeQYU2eZvKYlo2CIgl30FWy").
            to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://api.stripe.com/v1/invoices?starting_after=in_1KeQYU2eZvKYlo2CIgl60FWy").
            to_return(status: 200, body: page3_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.stripe.com/v1/invoices").
          to_return(status: 503, body: "uhh")
    end
  end

  describe "webhook validation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "stripe_invoice_v1") }
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
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "stripe_invoice_v1") }
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
          output: match("We've made an endpoint available for Stripe Invoice webhooks:"),
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
          output: match("Great! WebhookDB is now listening for Stripe Invoice webhooks."),
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
            "url": "/v1/invoices"
          }
        R
      end

      def stub_service_request
        return stub_request(:get, "https://api.stripe.com/v1/invoices").
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
          output: match("In order to backfill Stripe Invoices, we need an API key."),
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
          output: match("Great! We are going to start backfilling your Stripe Invoices."),
        )
      end
    end
  end
end
