# frozen_string_literal: true

require "grape"

require "webhookdb/api"
require "webhookdb/services"

class Webhookdb::API::Services < Webhookdb::API::V1
  resource :services do
    route_param :service_name, type: String do
      get :fixtures do
        begin
          svc = Webhookdb::Services.registered_service_type!(params[:service_name])
        rescue Webhookdb::Services::InvalidService
          merror!(403, "No service with that name exists.")
        end
        sint = Webhookdb::ServiceIntegration.new(table_name: params[:service_name] + "_fixture")
        sch = svc.call(sint).create_table_sql
        present({schema_sql: sch})
      end
    end
  end
end
