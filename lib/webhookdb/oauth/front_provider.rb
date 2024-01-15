# frozen_string_literal: true

require "webhookdb/front"

class Webhookdb::Oauth::FrontProvider < Webhookdb::Oauth::Provider
  include Appydays::Loggable

  # Override these for custom OAuth of different apps
  def key = "front"
  def app_name = "Front"
  def client_id = Webhookdb::Front.client_id
  def client_secret = Webhookdb::Front.client_secret

  def requires_webhookdb_auth? = true
  def supports_webhooks? = true

  def authorization_url(state:)
    return "https://app.frontapp.com/oauth/authorize?response_type=code&redirect_uri=#{self.callback_url}&state=#{state}&client_id=#{self.client_id}"
  end

  def callback_url = Webhookdb.api_url + "/v1/install/#{self.key}/callback"

  def exchange_authorization_code(code:)
    token = Webhookdb::Http.post(
      "https://app.frontapp.com/oauth/token",
      {
        "code" => code,
        "redirect_uri" => self.callback_url,
        "grant_type" => "authorization_code",
      },
      logger: self.logger,
      timeout: Webhookdb::Front.http_timeout,
      basic_auth: {username: self.client_id, password: self.client_secret},
    )
    return Webhookdb::Oauth::Tokens.new(
      access_token: token.parsed_response["access_token"],
      refresh_token: token.parsed_response["refresh_token"],
    )
  end

  def build_marketplace_integrations(organization:, tokens:, **)
    # I asked the dev team at front specifically how to differentiate between instances when receiving webhooks,
    # and they said to look at the root url of the link provided for the resource in every response. In order to
    # retrieve that value for the integrations that we'll be finding or creating, we look at this token info
    # response.
    front_token_info_resp = Webhookdb::Http.get(
      "https://api2.frontapp.com/me",
      headers: Webhookdb::Front.auth_headers(tokens.access_token),
      logger: self.logger,
      timeout: Webhookdb::Front.http_timeout,
    )
    front_token_info = front_token_info_resp.parsed_response
    resource_url = front_token_info.dig("_links", "self")
    instance_root_url = resource_url.nil? ? nil : URI.parse(resource_url).host

    root_sint = Webhookdb::ServiceIntegration.create_disambiguated(
      "front_marketplace_root_v1",
      organization:,
      api_url: instance_root_url,
      backfill_key: tokens.refresh_token,
    )
    root_sint.replicator.build_dependents
  end
end
