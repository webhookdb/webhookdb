# frozen_string_literal: true

require "webhookdb/front"

class Webhookdb::Oauth::Front < Webhookdb::Oauth::Provider
  include Appydays::Loggable

  def key = "front"
  def app_name = "Front"

  def authorization_url(state:)
    return "https://app.frontapp.com/oauth/authorize?response_type=code&redirect_uri=#{Webhookdb::Front.oauth_callback_url}&state=#{state}&client_id=#{Webhookdb::Front.client_id}"
  end

  def exchange_url = "https://app.frontapp.com/oauth/token"
  def redirect_url = Webhookdb::Front.oauth_callback_url
  def grant_type = "authorization_code"
  def basic_auth = {username: Webhookdb::Front.client_id, password: Webhookdb::Front.client_secret}

  def build_marketplace_integrations(organization:, access_token:, refresh_token:)
    # I asked the dev team at front specifically how to differentiate between instances when receiving webhooks,
    # and they said to look at the root url of the link provided for the resource in every response. In order to
    # retrieve that value for the integrations that we'll be finding or creating, we look at this token info
    # response.
    front_token_info_resp = Webhookdb::Http.get(
      "https://api2.frontapp.com/me",
      headers: Webhookdb::Front.auth_headers(access_token),
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
      backfill_key: refresh_token,
    )
    root_sint.replicator.build_dependents
  end
end
