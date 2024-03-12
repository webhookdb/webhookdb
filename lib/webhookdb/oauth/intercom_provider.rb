# frozen_string_literal: true

require "webhookdb/intercom"

class Webhookdb::Oauth::IntercomProvider < Webhookdb::Oauth::Provider
  include Appydays::Loggable

  def key = "intercom"
  def app_name = "Intercom"
  def supports_webhooks? = false

  def authorization_url(state:)
    return "https://app.intercom.com/oauth?client_id=#{Webhookdb::Intercom.client_id}&state=#{state}"
  end

  def exchange_authorization_code(code:)
    token_resp = Webhookdb::Http.post(
      "https://api.intercom.io/auth/eagle/token",
      {
        "client_id" => Webhookdb::Intercom.client_id,
        "client_secret" => Webhookdb::Intercom.client_secret,
        "code" => code,
      },
      logger: self.logger,
      timeout: Webhookdb::Intercom.http_timeout,
    )
    return Webhookdb::Oauth::Tokens.new(access_token: token_resp.parsed_response["token"])
  end

  def build_marketplace_integrations(organization:, tokens:)
    intercom_user_resp = Webhookdb::Http.get(
      "https://api.intercom.io/me",
      headers: Webhookdb::Intercom.auth_headers(tokens.access_token),
      logger: self.logger,
      timeout: Webhookdb::Intercom.http_timeout,
    )

    # The intercom workspace id is used in the intercom webhook endpoint to identify which
    # service integration to delegate requests to.
    intercom_workspace_id = intercom_user_resp.parsed_response.dig("app", "id_code")
    root_sint = Webhookdb::ServiceIntegration.create_disambiguated(
      "intercom_marketplace_root_v1",
      organization:,
      api_url: intercom_workspace_id,
      backfill_key: tokens.access_token,
    )
    root_sint.replicator.build_dependents
    return root_sint
  end
end
