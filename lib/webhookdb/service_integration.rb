# frozen_string_literal: true

require "webhookdb/postgres/model"

class Webhookdb::ServiceIntegration < Webhookdb::Postgres::Model(:service_integrations)
  plugin :timestamps
  plugin :soft_deletes
end
