# frozen_string_literal: true

require "webhookdb/http"

RSpec.describe Webhookdb::Http do
  describe "get" do
    it "calls HTTP GET" do
      req = stub_request(:get, "https://a.b").to_return(status: 200, body: "")
      qreq = stub_request(:get, "https://x.y/?x=1").to_return(status: 200, body: "")
      described_class.get("https://a.b", logger: nil)
      described_class.get("https://x.y", {x: 1}, logger: nil)
      expect(req).to have_been_made
      expect(qreq).to have_been_made
    end
    it "requires a :logger" do
      expect { described_class.get("https://x.y") }.to raise_error(ArgumentError, "must pass :logger keyword")
    end
    it "passes through options and merges headers" do
      req = stub_request(:get, "https://a.b/").
        with(
          headers: {
            "Abc" => "123",
            "Authorization" => "Basic dTpw",
            "User-Agent" => "WebhookDB/unknown-release https://webhookdb.com 1970-01-01T00:00:00Z",
          },
        ).
        to_return(status: 200, body: "", headers: {})
      described_class.get(
        "https://a.b",
        logger: nil,
        headers: {"ABC" => "123"},
        basic_auth: {username: "u", password: "p"},
      )
      expect(req).to have_been_made
    end
    it "errors on non-ok" do
      stub_request(:get, "https://a.b/").
        to_return(status: 500, body: "meh")

      expect { described_class.get("https://a.b", logger: nil) }.to raise_error(described_class::Error)
    end
  end
  describe "Error" do
    it "is rendered nicely" do
      stub_request(:get, "https://a.b/").
        to_return(status: 500, body: "meh", headers: {"X" => "y"})
      begin
        described_class.get("https://a.b", logger: nil)
      rescue Webhookdb::Http::Error => e
        nil
      end
      expect(e).to_not be_nil
      expect(e.to_s).to eq("HttpError(status: 500, uri: https://a.b/?, body: meh)")
    end
  end
end
