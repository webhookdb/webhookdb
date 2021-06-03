# frozen_string_literal: true

require "webhookdb/postgres/model"

class Webhookdb::OrganizationRole < Webhookdb::Postgres::Model(:organization_roles)
  def self.admin_role
    return Webhookdb.cached_get("role_admin") do
      self.find_or_create_or_find(name: "admin")
    end
  end

  one_to_many :organization_memberships, class: "Webhookdb::OrganizationMembership"
end
