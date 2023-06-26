# frozen_string_literal: true

require "appydays/configurable"
require "redis_client"

module Webhookdb::Redis
  include Appydays::Configurable

  class << self
    attr_accessor :cache
  end

  configurable(:redis) do
    setting :cache_redis_url, "redis://localhost:6379/0", key: ["CACHE_REDIS_URL", "REDIS_URL"]

    after_configured do
      cache_params = {url: self.cache_redis_url}
      cache_params[:ssl] = false if self.cache_redis_url.start_with?("rediss:") && ENV["HEROKU_APP_ID"]
      self.cache = ConnectionPool.new(
        size: Webhookdb::Dbutil.max_connections,
        timeout: Webhookdb::Dbutil.pool_timeout,
      ) do
        RedisClient.new(cache_params)
      end
    end
  end

  def self.cache_key(parts)
    tail = parts.join("/")
    return "cache/#{tail}"
  end
end
