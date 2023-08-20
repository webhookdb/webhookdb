# frozen_string_literal: true

require "grape"

require "webhookdb/api"
require "webhookdb/postgres"

# Health check and other metadata endpoints.
class Webhookdb::API::System < Webhookdb::Service
  format :json

  require "webhookdb/service/helpers"
  helpers Webhookdb::Service::Helpers

  get :healthz do
    Webhookdb::Postgres::Model.db.execute("SELECT 1=1")
    status 200
    {o: "k"}
  end

  get :statusz do
    status 200
    {
      env: Webhookdb::RACK_ENV,
      version: Webhookdb::VERSION,
      release: Webhookdb::RELEASE,
      log_level: Webhookdb.logger.level,
    }
  end

  resource :debug do
    get :echo do
      pp params.to_h
    end
  end
end
