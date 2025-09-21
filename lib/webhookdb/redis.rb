# frozen_string_literal: true

require "appydays/configurable"
require "redis_client"

require "webhookdb/dbutil"

module Webhookdb::Redis
  include Appydays::Configurable

  class << self
    attr_accessor :cache

    def conn_params(url, **kw)
      params = {url:}
      if url.start_with?("rediss:") && ENV["HEROKU_APP_ID"]
        # rediss: schema is Redis with SSL. They use self-signed certs, so we have to turn off SSL verification.
        # There is not a clear KB on this, you have to piece it together from Heroku and Sidekiq docs.
        params[:ssl_params] = {verify_mode: OpenSSL::SSL::VERIFY_NONE}
      end
      params.merge!(kw)
      return params
    end

    # Figure out the redis url to use. If +url_arg+ is present, use it.
    # It should be effectively `ENV['REDIS_URL']`.
    # Otherwise, use `ENV[provider]` if provider is present.
    # This should be like `ENV['REDIS_PROVIDER']`.
    def fetch_url(provider, url_arg)
      return url_arg if url_arg.present?
      return "" if provider.blank?
      return ENV.fetch(provider, "")
    end
  end

  configurable(:redis) do
    setting :cache_url, "redis://localhost:6379/0"
    setting :cache_url_provider, "REDIS_URL"

    after_configured do
      url = ENV.fetch(self.cache_url_provider, self.cache_url)
      cache_params = self.conn_params(url, reconnect_attempts: 1)
      redis_config = RedisClient.config(**cache_params)
      self.cache = redis_config.new_pool(
        timeout: Webhookdb::Dbutil.pool_timeout,
        size: Webhookdb::Dbutil.max_connections,
      )
    end
  end

  def self.cache_key(parts)
    parts = [parts] unless parts.respond_to?(:to_ary)
    tail = parts.join("/")
    return "cache/#{tail}"
  end
end
