# frozen_string_literal: true

require "webhookdb/postgres/model"

class Webhookdb::Organization < Webhookdb::Postgres::Model(:organizations)
  plugin :timestamps
  plugin :soft_deletes

  many_to_many :customers, class: "Webhookdb::Customer", join_table: :customers_organizations
  one_to_many :service_integrations, class: "Webhookdb::ServiceIntegration"
end
