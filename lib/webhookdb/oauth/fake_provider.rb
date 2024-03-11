# frozen_string_literal: true

require "webhookdb/increase"

class Webhookdb::Oauth::FakeProvider < Webhookdb::Oauth::Provider
  class << self
    # If any of these are non-nil, they're called instead of the instance method.
    attr_accessor :requires_webhookdb_auth, :supports_webhooks, :exchange_authorization_code

    def reset
      self.requires_webhookdb_auth = nil
      self.supports_webhooks = nil
      self.exchange_authorization_code = nil
    end
  end

  def key = "fake"
  def app_name = "Fake"
  def requires_webhookdb_auth? = _call_or_do(:requires_webhookdb_auth) { true }
  def supports_webhooks? = _call_or_do(:supports_webhooks) { true }

  def authorization_url(state:)
    return "#{Webhookdb.api_url}/v1/install/fake_oauth_authorization?client_id=fakeclient&state=#{state}"
  end

  def exchange_authorization_code(code:)
    return _call_or_do(:exchange_authorization_code) do
      Webhookdb::Oauth::Tokens.new(access_token: "access-#{code}", refresh_token: "refresh-#{code}")
    end
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

  protected def _call_or_do(m)
    d = Webhookdb::Oauth::FakeProvider.send(m)
    return yield if d.nil?
    return d.call
  end
end
