# frozen_string_literal: true

require "support/shared_examples_for_services"

RSpec.describe Webhookdb::Services::StripeInvoiceitemV1, :db do
  it_behaves_like "a service implementation", "stripe_invoiceitem_v1" do
    let(:body) do
      JSON.parse(<<~J)
        {
          "id": "evt_1CiPtv2eZvKYlo2CcUZsDcO6",
          "object": "event",
          "api_version": "2018-05-21",
          "created": 1530291411,
          "data": {
            "object": {
              "id": "ii_1Kgsrk2eZvKYlo2CiGktuBwD",
              "object": "invoiceitem",
              "amount": 399,
              "currency": "usd",
              "customer": "cus_AJ6yJU3BibDjl9",
              "date": 1648136784,
              "description": "My First Invoice Item (created for API docs)",
              "discountable": true,
              "discounts": [],
              "invoice": null,
              "livemode": false,
              "metadata": {},
              "period": {
                "end": 1648136784,
                "start": 1648136784
              },
              "price": {
                "id": "price_1KgsXf2eZvKYlo2CRONAcNsK",
                "object": "price",
                "active": true,
                "billing_scheme": "per_unit",
                "created": 1648135539,
                "currency": "usd",
                "livemode": false,
                "lookup_key": null,
                "metadata": {},
                "nickname": null,
                "product": "prod_LNdpykdq5QWGY7",
                "recurring": null,
                "tax_behavior": "unspecified",
                "tiers_mode": null,
                "transform_quantity": null,
                "type": "one_time",
                "unit_amount": 399,
                "unit_amount_decimal": "399"
              },
              "proration": false,
              "quantity": 1,
              "subscription": null,
              "tax_rates": [],
              "test_clock": null,
              "unit_amount": 399,
              "unit_amount_decimal": "399"
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
  it_behaves_like "a service implementation that prevents overwriting new data with old", "stripe_invoiceitem_v1" do
    let(:old_body) do
      JSON.parse(<<~J)
        {
          "id": "evt_1CiPtv2eZvKYlo2CcUZsDcO6",
          "object": "event",
          "api_version": "2018-05-21",
          "created": 1530291511,
          "data": {
            "object": {
              "id": "ii_1Kgsrk2eZvKYlo2CiGktuBwD",
              "object": "invoiceitem",
              "amount": 399,
              "currency": "usd",
              "customer": "cus_AJ6yJU3BibDjl9",
              "date": 1648136784,
              "description": "My First Invoice Item (created for API docs)",
              "discountable": true,
              "discounts": [],
              "invoice": null,
              "livemode": false,
              "metadata": {},
              "period": {
                "end": 1648136784,
                "start": 1648136784
              },
              "price": {
                "id": "price_1KgsXf2eZvKYlo2CRONAcNsK",
                "object": "price",
                "active": true,
                "billing_scheme": "per_unit",
                "created": 1648135539,
                "currency": "usd",
                "livemode": false,
                "lookup_key": null,
                "metadata": {},
                "nickname": null,
                "product": "prod_LNdpykdq5QWGY7",
                "recurring": null,
                "tax_behavior": "unspecified",
                "tiers_mode": null,
                "transform_quantity": null,
                "type": "one_time",
                "unit_amount": 399,
                "unit_amount_decimal": "399"
              },
              "proration": false,
              "quantity": 1,
              "subscription": null,
              "tax_rates": [],
              "test_clock": null,
              "unit_amount": 399,
              "unit_amount_decimal": "399"
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
          "created": 3530291611,
          "data": {
            "object": {
              "id": "ii_1Kgsrk2eZvKYlo2CiGktuBwD",
              "object": "invoiceitem",
              "amount": 399,
              "currency": "usd",
              "customer": "cus_AJ6yJU3BibDjl9",
              "date": 1648136784,
              "description": "My First Invoice Item (created for API docs)",
              "discountable": true,
              "discounts": [],
              "invoice": null,
              "livemode": false,
              "metadata": {},
              "period": {
                "end": 1648136784,
                "start": 1648136784
              },
              "price": {
                "id": "price_1KgsXf2eZvKYlo2CRONAcNsK",
                "object": "price",
                "active": true,
                "billing_scheme": "per_unit",
                "created": 1648135539,
                "currency": "usd",
                "livemode": false,
                "lookup_key": null,
                "metadata": {},
                "nickname": null,
                "product": "prod_LNdpykdq5QWGY7",
                "recurring": null,
                "tax_behavior": "unspecified",
                "tiers_mode": null,
                "transform_quantity": null,
                "type": "one_time",
                "unit_amount": 399,
                "unit_amount_decimal": "399"
              },
              "proration": false,
              "quantity": 1,
              "subscription": null,
              "tax_rates": [],
              "test_clock": null,
              "unit_amount": 399,
              "unit_amount_decimal": "399"
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

  it_behaves_like "a service implementation that deals with resources and wrapped events", "stripe_invoiceitem_v1" do
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
              "id": "ii_1Kgsrk2eZvKYlo2CiGktuBwD",
              "object": "invoiceitem",
              "amount": 399,
              "currency": "usd",
              "customer": "cus_AJ6yJU3BibDjl9",
              "date": 1648136784,
              "description": "My First Invoice Item (created for API docs)",
              "discountable": true,
              "discounts": [],
              "invoice": null,
              "livemode": false,
              "metadata": {},
              "period": {
                "end": 1648136784,
                "start": 1648136784
              },
              "price": {
                "id": "price_1KgsXf2eZvKYlo2CRONAcNsK",
                "object": "price",
                "active": true,
                "billing_scheme": "per_unit",
                "created": 1648135539,
                "currency": "usd",
                "livemode": false,
                "lookup_key": null,
                "metadata": {},
                "nickname": null,
                "product": "prod_LNdpykdq5QWGY7",
                "recurring": null,
                "tax_behavior": "unspecified",
                "tiers_mode": null,
                "transform_quantity": null,
                "type": "one_time",
                "unit_amount": 399,
                "unit_amount_decimal": "399"
              },
              "proration": false,
              "quantity": 1,
              "subscription": null,
              "tax_rates": [],
              "test_clock": null,
              "unit_amount": 399,
              "unit_amount_decimal": "399"
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

  it_behaves_like "a service implementation that verifies backfill secrets" do
    let(:correct_creds_sint) do
      Webhookdb::Fixtures.service_integration.create(
        service_name: "stripe_invoiceitem_v1",
        backfill_key: "bfkey",
      )
    end
    let(:incorrect_creds_sint) do
      Webhookdb::Fixtures.service_integration.create(
        service_name: "stripe_invoiceitem_v1",
        backfill_key: "bfkey_wrong",
      )
    end

    let(:success_body) do
      <<~R
        {
          "object": "list",
          "data": [],
          "has_more": false,
          "url": "/v1/invoiceitems"
        }
      R
    end
    def stub_service_request
      return stub_request(:get, "https://api.stripe.com/v1/invoiceitems").
          with(headers: {"Authorization" => "Basic YmZrZXk6"}).
          to_return(status: 200, body: success_body, headers: {})
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.stripe.com/v1/invoiceitems").
          with(headers: {"Authorization" => "Basic YmZrZXlfd3Jvbmc6"}).
          to_return(status: 403, body: "", headers: {})
    end
  end
  it_behaves_like "a service implementation that can backfill", "stripe_invoiceitem_v1" do
    let(:page1_response) do
      <<~R
        {
          "object": "list",
          "data": [
            {
              "id": "ii_1Kgsrk2eZvKYlo2CiGktuBwD",
              "object": "invoiceitem",
              "amount": 399,
              "currency": "usd",
              "customer": "cus_AJ6yJU3BibDjl9",
              "date": 1648136784,
              "description": "My First Invoice Item (created for API docs)",
              "discountable": true,
              "discounts": [],
              "invoice": null,
              "livemode": false,
              "metadata": {},
              "period": {
                "end": 1648136784,
                "start": 1648136784
              },
              "price": {
                "id": "price_1KgsXf2eZvKYlo2CRONAcNsK",
                "object": "price",
                "active": true,
                "billing_scheme": "per_unit",
                "created": 1648135539,
                "currency": "usd",
                "livemode": false,
                "lookup_key": null,
                "metadata": {},
                "nickname": null,
                "product": "prod_LNdpykdq5QWGY7",
                "recurring": null,
                "tax_behavior": "unspecified",
                "tiers_mode": null,
                "transform_quantity": null,
                "type": "one_time",
                "unit_amount": 399,
                "unit_amount_decimal": "399"
              },
              "proration": false,
              "quantity": 1,
              "subscription": null,
              "tax_rates": [],
              "test_clock": null,
              "unit_amount": 399,
              "unit_amount_decimal": "399"
            },
            {
              "id": "ii_1Kgsrk2eZvKYlo2CiGktuBwE",
              "object": "invoiceitem",
              "amount": 399,
              "currency": "usd",
              "customer": "cus_AJ6yJU3BibDjl9",
              "date": 1648136784,
              "description": "My First Invoice Item (created for API docs)",
              "discountable": true,
              "discounts": [],
              "invoice": null,
              "livemode": false,
              "metadata": {},
              "period": {
                "end": 1648136784,
                "start": 1648136784
              },
              "price": {
                "id": "price_1KgsXf2eZvKYlo2CRONAcNsK",
                "object": "price",
                "active": true,
                "billing_scheme": "per_unit",
                "created": 1648135539,
                "currency": "usd",
                "livemode": false,
                "lookup_key": null,
                "metadata": {},
                "nickname": null,
                "product": "prod_LNdpykdq5QWGY7",
                "recurring": null,
                "tax_behavior": "unspecified",
                "tiers_mode": null,
                "transform_quantity": null,
                "type": "one_time",
                "unit_amount": 399,
                "unit_amount_decimal": "399"
              },
              "proration": false,
              "quantity": 1,
              "subscription": null,
              "tax_rates": [],
              "test_clock": null,
              "unit_amount": 399,
              "unit_amount_decimal": "399"
            },
            {
              "id": "ii_1Kgsrk2eZvKYlo2CiGktuBwF",
              "object": "invoiceitem",
              "amount": 399,
              "currency": "usd",
              "customer": "cus_AJ6yJU3BibDjl9",
              "date": 1648136784,
              "description": "My First Invoice Item (created for API docs)",
              "discountable": true,
              "discounts": [],
              "invoice": null,
              "livemode": false,
              "metadata": {},
              "period": {
                "end": 1648136784,
                "start": 1648136784
              },
              "price": {
                "id": "price_1KgsXf2eZvKYlo2CRONAcNsK",
                "object": "price",
                "active": true,
                "billing_scheme": "per_unit",
                "created": 1648135539,
                "currency": "usd",
                "livemode": false,
                "lookup_key": null,
                "metadata": {},
                "nickname": null,
                "product": "prod_LNdpykdq5QWGY7",
                "recurring": null,
                "tax_behavior": "unspecified",
                "tiers_mode": null,
                "transform_quantity": null,
                "type": "one_time",
                "unit_amount": 399,
                "unit_amount_decimal": "399"
              },
              "proration": false,
              "quantity": 1,
              "subscription": null,
              "tax_rates": [],
              "test_clock": null,
              "unit_amount": 399,
              "unit_amount_decimal": "399"
            }
          ],
          "has_more": true,
          "url": "/v1/invoiceitems"
        }
      R
    end
    let(:page2_response) do
      <<~R
        {
          "object": "list",
          "data": [
            {
              "id": "ii_1Kgsrk2eZvKYlo2CiGktuBwG",
              "object": "invoiceitem",
              "amount": 399,
              "currency": "usd",
              "customer": "cus_AJ6yJU3BibDjl9",
              "date": 1648136784,
              "description": "My First Invoice Item (created for API docs)",
              "discountable": true,
              "discounts": [],
              "invoice": null,
              "livemode": false,
              "metadata": {},
              "period": {
                "end": 1648136784,
                "start": 1648136784
              },
              "price": {
                "id": "price_1KgsXf2eZvKYlo2CRONAcNsK",
                "object": "price",
                "active": true,
                "billing_scheme": "per_unit",
                "created": 1648135539,
                "currency": "usd",
                "livemode": false,
                "lookup_key": null,
                "metadata": {},
                "nickname": null,
                "product": "prod_LNdpykdq5QWGY7",
                "recurring": null,
                "tax_behavior": "unspecified",
                "tiers_mode": null,
                "transform_quantity": null,
                "type": "one_time",
                "unit_amount": 399,
                "unit_amount_decimal": "399"
              },
              "proration": false,
              "quantity": 1,
              "subscription": null,
              "tax_rates": [],
              "test_clock": null,
              "unit_amount": 399,
              "unit_amount_decimal": "399"
            },
            {
              "id": "ii_1Kgsrk2eZvKYlo2CiGktuBwH",
              "object": "invoiceitem",
              "amount": 399,
              "currency": "usd",
              "customer": "cus_AJ6yJU3BibDjl9",
              "date": 1648136784,
              "description": "My First Invoice Item (created for API docs)",
              "discountable": true,
              "discounts": [],
              "invoice": null,
              "livemode": false,
              "metadata": {},
              "period": {
                "end": 1648136784,
                "start": 1648136784
              },
              "price": {
                "id": "price_1KgsXf2eZvKYlo2CRONAcNsK",
                "object": "price",
                "active": true,
                "billing_scheme": "per_unit",
                "created": 1648135539,
                "currency": "usd",
                "livemode": false,
                "lookup_key": null,
                "metadata": {},
                "nickname": null,
                "product": "prod_LNdpykdq5QWGY7",
                "recurring": null,
                "tax_behavior": "unspecified",
                "tiers_mode": null,
                "transform_quantity": null,
                "type": "one_time",
                "unit_amount": 399,
                "unit_amount_decimal": "399"
              },
              "proration": false,
              "quantity": 1,
              "subscription": null,
              "tax_rates": [],
              "test_clock": null,
              "unit_amount": 399,
              "unit_amount_decimal": "399"
            },
            {
              "id": "ii_1Kgsrk2eZvKYlo2CiGktuBwj",
              "object": "invoiceitem",
              "amount": 399,
              "currency": "usd",
              "customer": "cus_AJ6yJU3BibDjl9",
              "date": 1648136784,
              "description": "My First Invoice Item (created for API docs)",
              "discountable": true,
              "discounts": [],
              "invoice": null,
              "livemode": false,
              "metadata": {},
              "period": {
                "end": 1648136784,
                "start": 1648136784
              },
              "price": {
                "id": "price_1KgsXf2eZvKYlo2CRONAcNsK",
                "object": "price",
                "active": true,
                "billing_scheme": "per_unit",
                "created": 1648135539,
                "currency": "usd",
                "livemode": false,
                "lookup_key": null,
                "metadata": {},
                "nickname": null,
                "product": "prod_LNdpykdq5QWGY7",
                "recurring": null,
                "tax_behavior": "unspecified",
                "tiers_mode": null,
                "transform_quantity": null,
                "type": "one_time",
                "unit_amount": 399,
                "unit_amount_decimal": "399"
              },
              "proration": false,
              "quantity": 1,
              "subscription": null,
              "tax_rates": [],
              "test_clock": null,
              "unit_amount": 399,
              "unit_amount_decimal": "399"
            }
          ],
          "has_more": true,
          "url": "/v1/invoiceitems"
        }
      R
    end
    let(:page3_response) do
      <<~R
        {
          "object": "list",
          "data": [],
          "has_more": false,
          "url": "/v1/invoiceitems"
        }
      R
    end
    let(:expected_items_count) { 6 }
    def stub_service_requests
      return [
        stub_request(:get, "https://api.stripe.com/v1/invoiceitems").
            with(headers: {"Authorization" => "Basic YmZrZXk6"}).
            to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://api.stripe.com/v1/invoiceitems?starting_after=ii_1Kgsrk2eZvKYlo2CiGktuBwF").
            to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://api.stripe.com/v1/invoiceitems?starting_after=ii_1Kgsrk2eZvKYlo2CiGktuBwj").
            to_return(status: 200, body: page3_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.stripe.com/v1/invoiceitems").
          to_return(status: 503, body: "uhh")
    end
  end

  describe "webhook validation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "stripe_invoiceitem_v1") }
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
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "stripe_invoiceitem_v1") }
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
          output: match("We've made an endpoint available for Stripe Invoiceitem webhooks:"),
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
          output: match("Great! WebhookDB is now listening for Stripe Invoiceitem webhooks."),
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
            "url": "/v1/invoiceitems"
          }
        R
      end

      def stub_service_request
        return stub_request(:get, "https://api.stripe.com/v1/invoiceitems").
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
          output: match("In order to backfill Stripe Invoiceitems, we need an API key."),
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
          output: match("Great! We are going to start backfilling your Stripe Invoiceitems."),
        )
      end
    end
  end
end
