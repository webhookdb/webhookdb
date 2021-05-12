# frozen_string_literal: true

require "webhookdb/postgres/model"

class Webhookdb::Organization < Webhookdb::Postgres::Model(:organizations)
  plugin :timestamps
  plugin :soft_deletes

  one_to_many :organization_memberships, class: "Webhookdb::OrganizationMembership"
  one_to_many :service_integrations, class: "Webhookdb::ServiceIntegration"
end
