# frozen_string_literal: true

require "webhookdb/plaid"

RSpec.describe Webhookdb::Plaid do
  describe "webhook_response" do
    it "is successful there is a Plaid verification header" do
      req = fake_request
      req.env["HTTP_PLAID_VERIFICATION"] = "a.b.c"
      status, _headers, _body = described_class.webhook_response(req, nil)
      expect(status).to eq(202)
    end

    it "returns a 401 for no wh auth header" do
      req = fake_request
      status, _headers, body = described_class.webhook_response(req, "a")
      expect(status).to eq(401)
      expect(body).to include("missing secret header")
    end

    it "returns 401 for a mismatched header" do
      req = fake_request
      req.env["HTTP_WHDB_WEBHOOK_SECRET"] = "b"
      status, _headers, body = described_class.webhook_response(req, "a")
      expect(status).to eq(401)
      expect(body).to include("secret mismatch")
    end

    it "returns a 200 with a valid header" do
      req = fake_request
      req.env["HTTP_WHDB_WEBHOOK_SECRET"] = "abcd"
      status, _headers, body = described_class.webhook_response(req, "abcd")
      expect(status).to eq(200)
    end
  end
end
