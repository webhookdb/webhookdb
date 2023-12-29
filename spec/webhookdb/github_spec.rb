# frozen_string_literal: true

require "webhookdb/github"

RSpec.describe Webhookdb::Github do
  describe "parses link header" do
    it "returns empty hash when link header string is empty" do
      expect(described_class.parse_link_header("")).to eq({})
    end

    # rubocop:disable Layout/LineLength
    it "parses presence of single link" do
      prev_link_header = '<https://api.github.com/repositories/1300192/issues?page=2>; rel="prev"'
      expect(described_class.parse_link_header(prev_link_header)).to include(prev: "https://api.github.com/repositories/1300192/issues?page=2")

      next_link_header = '<https://api.github.com/repositories/1300192/issues?page=2>; rel="next"'
      expect(described_class.parse_link_header(next_link_header)).to include(next: "https://api.github.com/repositories/1300192/issues?page=2")
    end

    it "parses presence of multiple links" do
      link_header = '<https://api.github.com/repositories/1300192/issues?page=2>; rel="prev", <https://api.github.com/repositories/1300192/issues?page=4>; rel="next"'
      expect(described_class.parse_link_header(link_header)).to include(
        prev: "https://api.github.com/repositories/1300192/issues?page=2",
        next: "https://api.github.com/repositories/1300192/issues?page=4",
      )
    end
    # rubocop:enable Layout/LineLength
  end

  describe "verifies webhook properly" do
    # See https://docs.github.com/en/webhooks/using-webhooks/validating-webhook-deliveries#testing-the-webhook-payload-validation
    it "returns false if auth info is incorrect" do
      body = "Hello, World!"
      webhook_secret = "It's a Secret to Everybody"
      header = "sha256=BAD"
      verified = described_class.verify_webhook(body, header, webhook_secret)
      expect(verified).to be(false)
    end

    it "returns true if auth info is correct" do
      body = "Hello, World!"
      webhook_secret = "It's a Secret to Everybody"
      header = "sha256=757107ea0eb2509fc211221cce984b8a37570b6d7586c22c46f4379c8b043e17"
      verified = described_class.verify_webhook(body, header, webhook_secret)
      expect(verified).to be(true)
    end
  end
end
