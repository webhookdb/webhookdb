# frozen_string_literal: true

require "webhookdb/postgres/model"

class Webhookdb::ServiceIntegration < Webhookdb::Postgres::Model(:service_integrations)
  plugin :timestamps
  plugin :soft_deletes

  many_to_one :organization, class: "Webhookdb::Organization"

  # @!attribute table_name
  #   @return [String] Name of the table

  # @!attribute service_name
  #   @return [String] Lookup name of the service
end
