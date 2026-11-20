# frozen_string_literal: true

require "webhookdb/increase"

class Webhookdb::Oauth::IncreaseProvider < Webhookdb::Oauth::Provider
  include Appydays::Loggable

  def key = "increase"
  def app_name = "Increase"
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
    group_id = group_resp.parsed_response.fetch("id")
    # We need to store the Oauth Connection ID for the group, so when there is an oauth disconnect,
    # we know which replicator to destroy.
    #
    # The deactivation comes through as an event on the Platform account,
    # and does not tell us the Group ID. And we cannot fetch the OAuth Connection
    # on the Platform account, since once a Connection is deactivated,
    # the Increase API will not return it.
    #
    # This seems like a bug, and has been reported to Increase.
    # If their /oauth_connections/:id endpoint starts working for 'inactive' connections,
    # this code can be removed, and we can look up the group ID when we handle the deactivate webhook.
    oauth_conns_resp = Webhookdb::Http.get(
      "https://api.increase.com/oauth_connections",
      headers: {"Authorization" => "Bearer #{Webhookdb::Increase.api_key}"},
      logger: self.logger,
      timeout: Webhookdb::Increase.http_timeout,
    )
    group_conn = oauth_conns_resp.parsed_response["data"].find { |c| c.fetch("group_id") == group_id }
    raise Webhookdb::InvariantViolation, "no OAuth Connection for Group #{group_id}/Org #{organization.key}" if
      group_conn.nil?
    root_sint = Webhookdb::ServiceIntegration.create_disambiguated(
      "increase_app_v1",
      organization:,
      api_url: group_id,
      backfill_key: tokens.access_token,
      webhookdb_api_key: group_conn.fetch("id"),
    )
    root_sint.replicator.build_dependents
    return root_sint
  end

  def self.disconnect_oauth(connection_id)
    # It may have already been deleted, make this idempotent.
    # See above for why we store the connection id directly.
    Webhookdb::ServiceIntegration.where(service_name: "increase_app_v1").
      with_encrypted_value(:webhookdb_api_key, connection_id).
      all.
      each(&:destroy_self_and_all_dependents)
  end
end
