# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::StripeCouponV1, :db do
  it_behaves_like "a replicator", "stripe_coupon_v1" do
    let(:body) do
      JSON.parse(<<~J)
        {
          "id": "evt_1CiPtv2eZvKYlo2CcUZsDcO6",
          "object": "event",
          "api_version": "2018-05-21",
          "created": 1530291411,
          "data": {
            "object": {
              "id": "Z4OV52SU",
              "object": "coupon",
              "amount_off": null,
              "created": 1648238146,
              "currency": "usd",
              "duration": "repeating",
              "duration_in_months": 3,
              "livemode": false,
              "max_redemptions": null,
              "metadata": {},
              "name": "25.5% off",
              "percent_off": 25.5,
              "redeem_by": null,
              "times_redeemed": 0,
              "valid": true#{'           '}
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
  it_behaves_like "a replicator that prevents overwriting new data with old", "stripe_coupon_v1" do
    let(:old_body) do
      JSON.parse(<<~J)
        {
          "id": "evt_1CiPtv2eZvKYlo2CcUZsDcO6",
          "object": "event",
          "api_version": "2018-05-21",
          "created": 1531291411,
          "data": {
            "object": {
              "id": "Z4OV52SU",
              "object": "coupon",
              "amount_off": null,
              "created": 1648238146,
              "currency": "usd",
              "duration": "repeating",
              "duration_in_months": 3,
              "livemode": false,
              "max_redemptions": null,
              "metadata": {},
              "name": "25.5% off",
              "percent_off": 25.5,
              "redeem_by": null,
              "times_redeemed": 0,
              "valid": true#{'           '}
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
          "created": 1532291411,
          "data": {
            "object": {
              "id": "Z4OV52SU",
              "object": "coupon",
              "amount_off": null,
              "created": 1648238146,
              "currency": "usd",
              "duration": "repeating",
              "duration_in_months": 3,
              "livemode": false,
              "max_redemptions": null,
              "metadata": {},
              "name": "25.5% off",
              "percent_off": 25.5,
              "redeem_by": null,
              "times_redeemed": 0,
              "valid": true#{'           '}
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

  it_behaves_like "a replicator that deals with resources and wrapped events", "stripe_coupon_v1" do
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
              "id": "Z4OV52SU",
              "object": "coupon",
              "amount_off": null,
              "created": 1649956427,
              "currency": "usd",
              "duration": "repeating",
              "duration_in_months": 3,
              "livemode": false,
              "max_redemptions": null,
              "metadata": {},
              "name": "25.5% off",
              "percent_off": 25.5,
              "redeem_by": null,
              "times_redeemed": 0,
              "valid": true
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
        service_name: "stripe_coupon_v1",
        backfill_key: "bfkey",
      )
    end
    let(:incorrect_creds_sint) do
      Webhookdb::Fixtures.service_integration.create(
        service_name: "stripe_coupon_v1",
        backfill_key: "bfkey_wrong",
      )
    end

    let(:success_body) do
      <<~R
        {
          "object": "list",
          "data": [],
          "has_more": false,
          "url": "/v1/coupons"
        }
      R
    end
    def stub_service_request
      return stub_request(:get, "https://api.stripe.com/v1/coupons").
          with(headers: {"Authorization" => "Basic YmZrZXk6"}).
          to_return(status: 200, body: success_body, headers: {})
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.stripe.com/v1/coupons").
          with(headers: {"Authorization" => "Basic YmZrZXlfd3Jvbmc6"}).
          to_return(status: 403, body: "", headers: {})
    end
  end
  it_behaves_like "a replicator that can backfill", "stripe_coupon_v1" do
    let(:page1_response) do
      <<~R
        {
          "object": "list",
          "data": [
            {
              "id": "Z4OV53SU",
              "object": "coupon",
              "amount_off": null,
              "created": 1648238146,
              "currency": "usd",
              "duration": "repeating",
              "duration_in_months": 3,
              "livemode": false,
              "max_redemptions": null,
              "metadata": {},
              "name": "25.5% off",
              "percent_off": 25.5,
              "redeem_by": null,
              "times_redeemed": 0,
              "valid": true
            },
            {
              "id": "Z4OV54SU",
              "object": "coupon",
              "amount_off": null,
              "created": 1648238146,
              "currency": "usd",
              "duration": "repeating",
              "duration_in_months": 3,
              "livemode": false,
              "max_redemptions": null,
              "metadata": {},
              "name": "25.5% off",
              "percent_off": 25.5,
              "redeem_by": null,
              "times_redeemed": 0,
              "valid": true
            },
            {
              "id": "Z4OV55SU",
              "object": "coupon",
              "amount_off": null,
              "created": 1648238146,
              "currency": "usd",
              "duration": "repeating",
              "duration_in_months": 3,
              "livemode": false,
              "max_redemptions": null,
              "metadata": {},
              "name": "25.5% off",
              "percent_off": 25.5,
              "redeem_by": null,
              "times_redeemed": 0,
              "valid": true
            }
          ],
          "has_more": true,
          "url": "/v1/coupon"
        }
      R
    end
    let(:page2_response) do
      <<~R
        {
          "object": "list",
          "data": [
            {
              "id": "Z4OV56SU",
              "object": "coupon",
              "amount_off": null,
              "created": 1648238146,
              "currency": "usd",
              "duration": "repeating",
              "duration_in_months": 3,
              "livemode": false,
              "max_redemptions": null,
              "metadata": {},
              "name": "25.5% off",
              "percent_off": 25.5,
              "redeem_by": null,
              "times_redeemed": 0,
              "valid": true
            },
            {
              "id": "Z4OV57SU",
              "object": "coupon",
              "amount_off": null,
              "created": 1648238146,
              "currency": "usd",
              "duration": "repeating",
              "duration_in_months": 3,
              "livemode": false,
              "max_redemptions": null,
              "metadata": {},
              "name": "25.5% off",
              "percent_off": 25.5,
              "redeem_by": null,
              "times_redeemed": 0,
              "valid": true
            },
            {
              "id": "Z4OV58SU",
              "object": "coupon",
              "amount_off": null,
              "created": 1648238146,
              "currency": "usd",
              "duration": "repeating",
              "duration_in_months": 3,
              "livemode": false,
              "max_redemptions": null,
              "metadata": {},
              "name": "25.5% off",
              "percent_off": 25.5,
              "redeem_by": null,
              "times_redeemed": 0,
              "valid": true
            }
          ],
          "has_more": true,
          "url": "/v1/coupon"
        }
      R
    end
    let(:page3_response) do
      <<~R
        {
          "object": "list",
          "data": [],
          "has_more": false,
          "url": "/v1/coupons"
        }
      R
    end
    let(:expected_items_count) { 6 }
    def stub_service_requests
      return [
        stub_request(:get, "https://api.stripe.com/v1/coupons").
            with(headers: {"Authorization" => "Basic YmZrZXk6"}).
            to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://api.stripe.com/v1/coupons?starting_after=Z4OV55SU").
            to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://api.stripe.com/v1/coupons?starting_after=Z4OV58SU").
            to_return(status: 200, body: page3_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_empty_requests
      return [
        stub_request(:get, "https://api.stripe.com/v1/coupons").
            to_return(status: 200, body: page3_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.stripe.com/v1/coupons").
          to_return(status: 503, body: "uhh")
    end
  end

  describe "webhook validation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "stripe_coupon_v1") }
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
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "stripe_coupon_v1") }
    let(:svc) { Webhookdb::Replicator.create(sint) }

    describe "calculate_create_state_machine" do
      it "asks for webhook secret" do
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: "Paste or type your secret here:",
          prompt_is_secret: true,
          post_to_url: end_with("/service_integrations/#{sint.opaque_id}/transition/webhook_secret"),
          complete: false,
          output: match("We've made an endpoint available for Stripe Coupon webhooks:"),
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
          output: match("Great! WebhookDB is now listening for Stripe Coupon webhooks."),
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
            "url": "/v1/coupons"
          }
        R
      end

      def stub_service_request
        return stub_request(:get, "https://api.stripe.com/v1/coupons").
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
          output: match("In order to backfill Stripe Coupons, we need an API key."),
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
          output: match("Great! We are going to start backfilling your Stripe Coupons."),
        )
      end
    end
  end
end
