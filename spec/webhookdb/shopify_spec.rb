# frozen_string_literal: true

require "webhookdb/shopify"

RSpec.describe "Webhookdb::Shopify" do
  describe "parses link header" do
    it "returns empty hash when link header string is empty" do
      expect(Webhookdb::Shopify.parse_link_header("")).to eq({})
    end
    # rubocop:disable Layout/LineLength
    it "parses presence of single link" do
      prev_link_header = '<https://shop-domain.myshopify.com/admin/api/2019-07/products.json?limit=50&page_info=eyJkaXJlY3>; rel="previous"'
      expect(Webhookdb::Shopify.parse_link_header(prev_link_header)).to have_key(:previous)
      expect(Webhookdb::Shopify.parse_link_header(prev_link_header)).to have_value("https://shop-domain.myshopify.com/admin/api/2019-07/products.json?limit=50&page_info=eyJkaXJlY3")

      next_link_header = '<https://shop-domain.myshopify.io/admin/api/2019-07/products.json?limit=250&page_info=eyJsYXN0X2>; rel="next"'
      expect(Webhookdb::Shopify.parse_link_header(next_link_header)).to have_key(:next)
      expect(Webhookdb::Shopify.parse_link_header(next_link_header)).to have_value("https://shop-domain.myshopify.io/admin/api/2019-07/products.json?limit=250&page_info=eyJsYXN0X2")
    end
    it "parses presence of multiple links" do
      link_header = '<https://shop-domain.myshopify.com/admin/api/2019-07/products.json?limit=50&page_info=eyJkaXJlY3>; rel="previous", <https://shop-domain.myshopify.io/admin/api/2019-07/products.json?limit=250&page_info=eyJsYXN0X2>; rel="next"'
      expect(Webhookdb::Shopify.parse_link_header(link_header)).to have_key(:previous)
      expect(Webhookdb::Shopify.parse_link_header(link_header)).to have_value("https://shop-domain.myshopify.com/admin/api/2019-07/products.json?limit=50&page_info=eyJkaXJlY3")
      expect(Webhookdb::Shopify.parse_link_header(link_header)).to have_key(:next)
      expect(Webhookdb::Shopify.parse_link_header(link_header)).to have_value("https://shop-domain.myshopify.io/admin/api/2019-07/products.json?limit=250&page_info=eyJsYXN0X2")
    end
    # rubocop:enable Layout/LineLength
  end

  describe "verifies webhook properly" do
    it "returns false if auth info is incorrect" do
      # just using random auth info here
      webhook_secret = "asdf5678"
      hmac_header = "6ffbb59b2300aae63f272406069a9788598b792a944a07aba816edb039989a39"
      verified = Webhookdb::Shopify.verify_webhook("asdfghujkl", hmac_header, webhook_secret)
      expect(verified).to eq(false)
    end
    it "returns true if auth info is correct" do
      webhook_secret = "asdf5678"
      request_data = "asdfghujkl"
      hmac_header = Base64.strict_encode64(OpenSSL::HMAC.digest("sha256", webhook_secret, request_data))
      verified = Webhookdb::Shopify.verify_webhook(request_data, hmac_header, webhook_secret)
      expect(verified).to eq(true)
    end
  end
end
