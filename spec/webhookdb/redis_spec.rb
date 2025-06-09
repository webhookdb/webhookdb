# frozen_string_literal: true

require "webhookdb/redis"

RSpec.describe Webhookdb::Redis do
  describe "cache_key" do
    it "returns a namespaced cache key" do
      expect(described_class.cache_key("key")).to eq("cache/key")
      expect(described_class.cache_key(["key"])).to eq("cache/key")
      expect(described_class.cache_key(["key", "x"])).to eq("cache/key/x")
    end
  end
end
