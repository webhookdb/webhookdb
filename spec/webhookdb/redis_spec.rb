# frozen_string_literal: true

require "webhookdb/redis"

RSpec.describe Webhookdb::Redis do
  describe "#fetch_url" do
    let(:envname) { "_WHDBTEST_REDIS_URL" }

    it "returns the url if not blank" do
      expect(described_class.fetch_url(envname, "x")).to eq("x")
    end

    it "returns the value of the env var if url is blank" do
      ENV[envname] = "y"
      expect(described_class.fetch_url(envname, "")).to eq("y")
      expect(described_class.fetch_url(envname, nil)).to eq("y")
      expect(described_class.fetch_url(envname, " ")).to eq("y")
    end
  end

  describe "#conn_params" do
    it "returns keyword arguments" do
      params = described_class.conn_params("redis://localhost:1234/0", reconnect_attempts: 1, timeout: 1.0)
      expect(params).to include(url: "redis://localhost:1234/0", reconnect_attempts: 1, timeout: 1.0)
    end

    it "returns ssl_params when using heroku redis" do
      ssl_schema_url = "rediss://"
      none_ssl_schema_url = "redis://"

      expect(described_class.conn_params(none_ssl_schema_url)).to_not include(:ssl_params)
      expect(described_class.conn_params(ssl_schema_url)).to_not include(:ssl_params)
      ENV["HEROKU_APP_ID"] = "a1b2bc"
      expect(described_class.conn_params(ssl_schema_url)).to include(ssl_params: {verify_mode: 0})
      expect(described_class.conn_params(none_ssl_schema_url)).to_not include(:ssl_params)
    end
  end

  describe "cache_key" do
    it "returns a namespaced cache key" do
      expect(described_class.cache_key("key")).to eq("cache/key")
      expect(described_class.cache_key(["key"])).to eq("cache/key")
      expect(described_class.cache_key(["key", "x"])).to eq("cache/key/x")
    end
  end
end
