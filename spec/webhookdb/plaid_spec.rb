# frozen_string_literal: true

require "webhookdb/plaid"

RSpec.describe Webhookdb::Plaid do
  describe "webhook_response" do
    it "is successful there is a Plaid verification header" do
      req = fake_request
      req.env["HTTP_PLAID_VERIFICATION"] = "a.b.c"
      whresp = described_class.webhook_response(req, nil)
      expect(whresp).to have_attributes(status: 202)
    end

    it "returns a 401 for no wh auth header" do
      req = fake_request
      whresp = described_class.webhook_response(req, "a")
      expect(whresp).to have_attributes(status: 401, reason: "missing secret header")
    end

    it "returns 401 for a mismatched header" do
      req = fake_request
      req.env["HTTP_WHDB_WEBHOOK_SECRET"] = "b"
      whresp = described_class.webhook_response(req, "a")
      expect(whresp).to have_attributes(status: 401, reason: "secret mismatch")
    end

    it "returns a 200 with a valid header" do
      req = fake_request
      req.env["HTTP_WHDB_WEBHOOK_SECRET"] = "abcd"
      whresp = described_class.webhook_response(req, "abcd")
      expect(whresp).to have_attributes(status: 200)
    end
  end
end
