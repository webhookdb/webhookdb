# frozen_string_literal: true

require "grape"

require "webhookdb/api"
require "webhookdb/services"

class Webhookdb::API::Services < Webhookdb::API::V1
  resource :services do
    route_param :service_name, type: String do
      get :fixtures do
        begin
          descr = Webhookdb::Services.registered_service!(params[:service_name])
        rescue Webhookdb::Services::InvalidService
          merror!(403, "No service with that name exists.")
        end
        sint = Webhookdb::ServiceIntegration.new(
          opaque_id: "svi_fixture",
          table_name: params[:service_name] + "_fixture",
        )
        sch = descr.ctor.call(sint).create_table_modification.to_s
        present({schema_sql: sch})
      end
    end
  end
end
