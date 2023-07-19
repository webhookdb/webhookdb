# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::StripeRefundV1, :db do
  it_behaves_like "a replicator", "stripe_refund_v1" do
    let(:body) do
      JSON.parse(<<~J)
        {
          "id": "evt_1CiPtv2eZvKYlo2CcUZsDcO6",
          "object": "event",
          "api_version": "2018-05-21",
          "created": 1530291411,
          "data": {
            "object": {
              "id": "re_3Ke0Br2eZvKYlo2C1MfCYAM9",
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
  it_behaves_like "a replicator that prevents overwriting new data with old", "stripe_refund_v1" do
    let(:old_body) do
      JSON.parse(<<~J)
        {
          "id": "evt_1CiPtv2eZvKYlo2CcUZsDcO6",
          "object": "event",
          "api_version": "2018-05-21",
          "created": 1530291410,
          "data": {
            "object": {
              "id": "re_3Ke0Br2eZvKYlo2C1MfCYAM9",
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
          "created": 1530291412,
          "data": {
            "object": {
              "id": "re_3Ke0Br2eZvKYlo2C1MfCYAM9",
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

  it_behaves_like "a replicator that deals with resources and wrapped events", "stripe_refund_v1" do
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
              "id": "re_3Ke0Br2eZvKYlo2C1MfCYAM9",
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
  it_behaves_like "a replicator that can backfill", "stripe_refund_v1" do
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
          to_return(status: 503, body: "uhh")
    end
  end
  describe "webhook validation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "stripe_refund_v1") }
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
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "stripe_refund_v1") }
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
end
