# frozen_string_literal: true

require "webhookdb/postgres"

class Webhookdb::OauthSession < Webhookdb::Postgres::Model(:oauth_sessions)
  plugin :timestamps

  many_to_one :customer, class: "Webhookdb::Customer"
  many_to_one :organization, class: "Webhookdb::Organization"

  def self.params_for_request(request)
    return {
      peer_ip: request.ip,
      user_agent: request.user_agent || "(unset)",
    }
  end
end
