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

# Table: oauth_sessions
# -------------------------------------------------------------------------------------------------------
# Columns:
#  id                 | integer                  | PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY
#  created_at         | timestamp with time zone | NOT NULL DEFAULT now()
#  customer_id        | integer                  |
#  organization_id    | integer                  |
#  user_agent         | text                     | NOT NULL
#  peer_ip            | inet                     | NOT NULL
#  oauth_state        | text                     | NOT NULL
#  authorization_code | text                     |
#  used_at            | timestamp with time zone |
# Indexes:
#  oauth_sessions_pkey              | PRIMARY KEY btree (id)
#  oauth_sessions_customer_id_index | btree (customer_id)
# Foreign key constraints:
#  oauth_sessions_customer_id_fkey     | (customer_id) REFERENCES customers(id) ON DELETE CASCADE
#  oauth_sessions_organization_id_fkey | (organization_id) REFERENCES organizations(id) ON DELETE CASCADE
# -------------------------------------------------------------------------------------------------------
