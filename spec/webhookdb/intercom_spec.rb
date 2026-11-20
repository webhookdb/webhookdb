# frozen_string_literal: true

require "webhookdb/intercom"

RSpec.describe Webhookdb::Intercom do
  describe "webhook validation" do
    let(:req) { fake_request(input: '{"data": "asdfghujkl"}') }
    let(:data) { req.body }
    let(:secret) { "webhook_secret" }

    describe "webhook_response" do
      it "returns a 401 if there is no signature header" do
        resp = described_class.webhook_response(req, "webhook_secret")
        expect(resp).to have_attributes(status: 401, reason: "missing hmac")
      end

      it "returns a 401 for an invalid signature" do
        req.add_header("HTTP_X_HUB_SIGNATURE", "sha1=invalid")
        resp = described_class.webhook_response(req, secret)
        expect(resp).to have_attributes(status: 401, reason: "invalid hmac")
      end

      it "returns a 202 if the signature is valid" do
        req.add_header("HTTP_X_HUB_SIGNATURE", "sha1=#{OpenSSL::HMAC.hexdigest('SHA1', secret, data)}")
        resp = described_class.webhook_response(req, secret)
        expect(resp).to have_attributes(status: 202)
      end
    end
  end
end
