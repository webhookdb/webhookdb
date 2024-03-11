# frozen_string_literal: true

require "webhookdb/increase"

class Webhookdb::Oauth::FakeProvider < Webhookdb::Oauth::Provider
  class << self
    attr_accessor :requires_webhookdb_auth
  end

  def key = "fake"
  def app_name = "Fake"
  def requires_webhookdb_auth? = Webhookdb::Oauth::FakeProvider.requires_webhookdb_auth
  def supports_webhooks? = true

  def authorization_url(state:)
    return "#{Webhookdb.api_url}/v1/install/fake_oauth_authorization?client_id=fakeclient&state=#{state}"
  end

  def exchange_authorization_code(code:)
    return Webhookdb::Oauth::Tokens.new(access_token: "access-#{code}", refresh_token: "refresh-#{code}")
  end

  def find_or_create_customer(tokens:, **)
    return Webhookdb::Customer.find_or_create_for_email("#{tokens.access_token}@webhookdb.com")
  end

  def build_marketplace_integrations(organization:, tokens:, **)
    return Webhookdb::ServiceIntegration.create_disambiguated(
      "fake_v1",
      organization:,
      webhook_secret: tokens.access_token,
      backfill_key: tokens.refresh_token,
    )
  end
end
