# frozen_string_literal: true

require "webhookdb/postgres"
require "webhookdb/oauth"

class Webhookdb::Oauth::Session < Webhookdb::Postgres::Model(:oauth_sessions)
  plugin :timestamps

  many_to_one :customer, class: "Webhookdb::Customer"
  many_to_one :organization, class: "Webhookdb::Organization"

  dataset_module do
    def usable
      return self.where(used_at: nil).where { created_at > 30.minutes.ago }
    end
  end

  def self.params_for_request(request)
    return {
      peer_ip: request.ip,
      user_agent: request.user_agent || "(unset)",
    }
  end
end
