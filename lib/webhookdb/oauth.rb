# frozen_string_literal: true

module Webhookdb::Oauth
  class Tokens < Webhookdb::TypedStruct
    attr_reader :access_token, :refresh_token

    def initialize(**kwargs)
      super
      self.typecheck!(:access_token, String)
      self.typecheck!(:refresh_token, String, nullable: true)
    end
  end

  class Provider
    # @return [String] Unique key to identify the provider.
    def key = raise NotImplementedError

    # @return [String] Name of the app to present to users.
    def app_name = raise NotImplementedError

    # This is similar to `supports_webhooks` in the Replicator descriptors,
    # except that this is used to make the success page dynamic.
    # True if this provider's integrations support webhooks
    # (real-time or user-built webhook payloads).
    def supports_webhooks? = raise NotImplementedError

    # @return [String] The Oauth URL to send users to to begin OAuth.
    def authorization_url(state:) = raise NotImplementedError

    # Exchange the access code (from the authorization url) for access and/or refresh tokens.
    # @return [Webhookdb::Oauth::Tokens]
    def exchange_authorization_code(code:) = raise NotImplementedError

    # Create the actual service integrations for the given org.
    # @param organization [Webhookdb::Organization]
    # @param tokens [Webhookdb::Oauth::Tokens]
    # @return [Webhookdb::ServiceIntegration]
    def build_marketplace_integrations(organization:, tokens:) = raise NotImplementedError
end
  class << self
    def register(cls)
      key = cls.new.key
      raise KeyError, "#{key} already registered to #{cls}" if self.registry.include?(key)
      self.registry[key] = cls
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

require "webhookdb/oauth/fake_provider"
Webhookdb::Oauth.register(Webhookdb::Oauth::FakeProvider)
require "webhookdb/oauth/front_provider"
Webhookdb::Oauth.register(Webhookdb::Oauth::FrontProvider)
Webhookdb::Oauth.register(Webhookdb::Oauth::FrontSignalwireChannelProvider)
require "webhookdb/oauth/increase_provider"
Webhookdb::Oauth.register(Webhookdb::Oauth::IncreaseProvider)
require "webhookdb/oauth/intercom_provider"
Webhookdb::Oauth.register(Webhookdb::Oauth::IntercomProvider)
