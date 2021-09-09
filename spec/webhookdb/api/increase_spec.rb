# frozen_string_literal: true

require "webhookdb/increase"

RSpec.describe "Webhookdb::Increase" do
  let(:described_class) { Webhookdb::Increase }

  describe "webhook_response" do
    it "returns a 401 as per spec if there is no Authorization header" do
      req = fake_request
      data = req.body
      status, headers, _body = Webhookdb::Increase.webhook_response(req, "webhook_secret")
      expect(status).to eq(401)
    end

    it "returns a 401 for an invalid Authorization header" do
      req = fake_request(input: '{"data": "asdfghujkl"}')
      data = req.body
      computed_auth = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), "webhook_secret", '{"data": "foobar"}')
      req.add_header("x-bank-webhook-signature", computed_auth)
      status, _headers, body = Webhookdb::Increase.webhook_response(req, "webhook_secret")
      expect(status).to eq(401)
      expect(body).to include("invalid hmac")
    end

    it "returns a 200 with a valid Authorization header" do
      req = fake_request(input: '{"data": "asdfghujkl"}')
      data = req.body
      computed_auth = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), "webhook_secret", data)
      req.add_header("x-bank-webhook-signature", computed_auth)
      status, _headers, _body = Webhookdb::Increase.webhook_response(req, "webhook_secret")
      expect(status).to eq(200)
    end
  end
end
