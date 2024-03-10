# frozen_string_literal: true

require "webhookdb/increase"

class Webhookdb::Oauth::IncreaseProvider < Webhookdb::Oauth::Provider
  include Appydays::Loggable

  def key = "increase"
  def app_name = "Increase"
  # We cannot get the authed user from the Increase OAuth token
  def requires_webhookdb_auth? = true
  # Increase POSTs all Oauth app webhooks to the same place
  def supports_webhooks? = true

  def authorization_url(state:)
    return "https://increase.com/oauth/authorization?client_id=#{Webhookdb::Increase.oauth_client_id}&state=#{state}&scope=read_only"
  end

  def exchange_authorization_code(code:)
    token_resp = Webhookdb::Http.post(
      "https://api.increase.com/oauth/tokens",
      {
        "client_id" => Webhookdb::Increase.oauth_client_id,
        "client_secret" => Webhookdb::Increase.oauth_client_secret,
        "code" => code,
        grant_type: "authorization_code",
      },
      headers: {"Authorization" => "Bearer #{Webhookdb::Increase.api_key}"},
      logger: self.logger,
      timeout: Webhookdb::Increase.http_timeout,
    )
    return Webhookdb::Oauth::Tokens.new(access_token: token_resp.parsed_response["access_token"])
  end

  def build_marketplace_integrations(organization:, tokens:, **)
    group_resp = Webhookdb::Http.get(
      "https://api.increase.com/groups/current",
      headers: {"Authorization" => "Bearer #{tokens.access_token}"},
      logger: self.logger,
      timeout: Webhookdb::Increase.http_timeout,
    )
    root_sint = Webhookdb::ServiceIntegration.create_disambiguated(
      "increase_app_v1",
      organization:,
      api_url: group_resp.parsed_response.fetch("id"),
      backfill_key: tokens.access_token,
    )
    root_sint.replicator.build_dependents
    return root_sint
  end
end
