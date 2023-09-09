# frozen_string_literal: true

module Webhookdb::Oauth
  class Provider
    def key = raise NotImplementedError
    def app_name = raise NotImplementedError
    def authorization_url(state:) = raise NotImplementedError
    def exchange_url = raise NotImplementedError
    def redirect_url = raise NotImplementedError
    def grant_type = raise NotImplementedError
    def basic_auth = raise NotImplementedError
    def build_marketplace_integrations(organization:, access_token:, refresh_token:) = raise NotImplementedError
  end

  class << self
    # @return [String, Class]
    def register(key, cls)
      self.registry[key] ||= cls
    end

    # @return [Provider]
    def provider(key)
      return self.registry.fetch(key).new
    end

    # @return [Hash]
    def registry
      return @registry ||= {}
    end
  end
end

require "webhookdb/oauth/front"
Webhookdb::Oauth.register(Webhookdb::Oauth::Front.new.key, Webhookdb::Oauth::Front)
