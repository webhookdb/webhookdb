# frozen_string_literal: true

require "webhookdb/stripe"

RSpec.describe "Webhookdb::Stripe" do
  let(:described_class) { Webhookdb::Stripe }

  describe "webhook_response" do
    it "returns a 401 as per spec if there is no Authorization header" do
      req = fake_request
      data = req.body
      whresp = Webhookdb::Stripe.webhook_response(req, Webhookdb::Stripe.webhook_secret)
      expect(whresp).to have_attributes(status: 401)
    end

    it "returns a 401 for an invalid Authorization header" do
      Webhookdb::Stripe.webhook_secret = "user:pass"
      req = fake_request(input: '{"data": "asdfghujkl"}')
      data = req.body
      req.add_header("HTTP_STRIPE_SIGNATURE",
                     "t=1492774577,v1=5257a869e7ecebeda32affa62cdca3fa51cad7e77a0e56ff536d0ce8e108d8bd",)
      whresp = Webhookdb::Stripe.webhook_response(req, Webhookdb::Stripe.webhook_secret)
      expect(whresp).to have_attributes(status: 401, reason: "invalid hmac")
    end

    it "returns a 202 with a valid Authorization header" do
      Webhookdb::Stripe.webhook_secret = "user:pass"
      req = fake_request(input: '{"data": "asdfghujkl"}')
      data = req.body
      timestamp = Time.now
      stripe_signature = "t=" + timestamp.to_i.to_s + ",v1=" # this is the interim value
      stripe_signature += Stripe::Webhook::Signature.compute_signature(timestamp, data,
                                                                       Webhookdb::Stripe.webhook_secret,)
      req.add_header("HTTP_STRIPE_SIGNATURE", stripe_signature)
      whresp = Webhookdb::Stripe.webhook_response(req, Webhookdb::Stripe.webhook_secret)
      expect(whresp).to have_attributes(status: 202)
    end
  end
end
