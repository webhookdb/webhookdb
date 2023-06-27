# frozen_string_literal: true

require "appydays/configurable"
require "redis_client"

module Webhookdb::Redis
  include Appydays::Configurable

  class << self
    attr_accessor :cache
  end

  configurable(:redis) do
    setting :cache_url, "redis://localhost:6379/0"
    setting :cache_url_provider, "REDIS_URL"
    setting :verify_ssl, false

    after_configured do
      url = ENV.fetch(self.cache_url_provider, self.cache_url)
      cache_params = {url:, reconnect_attempts: 1}
      cache_params[:ssl_params] = {verify_mode: OpenSSL::SSL::VERIFY_NONE} unless
        self.verify_ssl
      redis_config = RedisClient.config(**cache_params)
      self.cache = redis_config.new_pool(
        timeout: Webhookdb::Dbutil.pool_timeout,
        size: Webhookdb::Dbutil.max_connections,
      )
    end
  end

  def self.cache_key(parts)
    tail = parts.join("/")
    return "cache/#{tail}"
  end
end
