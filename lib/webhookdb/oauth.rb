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

  # rubocop:disable Lint/UnusedMethodArgument
  class Provider
    # @return [String] Unique key to identify the provider.
    def key = raise NotImplementedError

    # @return [String] Name of the app to present to users.
    def app_name = raise NotImplementedError

    # True if auth with this provider requires the user auth in WebhookDB,
    # false if we can get their email from the Oauth process.
    # If the access token can be used to get the 'me' user,
    # we can usually use their email for the customer,
    # but this may not be possible for some integrations.
    def requires_webhookdb_auth? = raise NotImplementedError

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

    # @param tokens [Webhookdb::Oauth::Tokens]
    # @param scope [Hash] Used to store data needed in later calls, like when building integrations.
    # @return [Array{TrueClass, FalseClass, Webhookdb::Customer}]
    def find_or_create_customer(tokens:, scope:)
      raise RuntimeError("should not be called") if self.requires_webhookdb_auth?
      raise NotImplementedError
    end

    # Create the actual service integrations for the given org.
    # @param organization [Webhookdb::Organization]
    # @param tokens [Webhookdb::Oauth::Tokens]
    # # @param scope [Hash]
    def build_marketplace_integrations(organization:, tokens:, scope:) = raise NotImplementedError
  end
  # rubocop:enable Lint/UnusedMethodArgument

  class << self
    # @return [String, Class]
    def register(key, cls)
      raise "#{key} already registered to #{cls}" if self.registry.include?(key)
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

require "webhookdb/oauth/front"
Webhookdb::Oauth.register(Webhookdb::Oauth::Front.new.key, Webhookdb::Oauth::Front)
require "webhookdb/oauth/intercom"
Webhookdb::Oauth.register(Webhookdb::Oauth::Intercom.new.key, Webhookdb::Oauth::Intercom)
