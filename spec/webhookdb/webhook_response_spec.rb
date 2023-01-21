# frozen_string_literal: true

require "webhookdb/webhook_response"

RSpec.describe Webhookdb::WebhookResponse do
  describe "for_standard_secret" do
    it "returns a 401 for no wh auth header" do
      req = fake_request
      whresp = described_class.for_standard_secret(req, "a")
      expect(whresp).to have_attributes(status: 401, reason: "missing secret header")
    end

    it "returns 401 for a mismatched header" do
      req = fake_request
      req.env["HTTP_WHDB_WEBHOOK_SECRET"] = "b"
      whresp = described_class.for_standard_secret(req, "a")
      expect(whresp).to have_attributes(status: 401, reason: "secret mismatch")
    end

    it "returns a 202 with a valid header" do
      req = fake_request
      req.env["HTTP_WHDB_WEBHOOK_SECRET"] = "abcd"
      whresp = described_class.for_standard_secret(req, "abcd")
      expect(whresp).to have_attributes(status: 202)
    end
  end
end
