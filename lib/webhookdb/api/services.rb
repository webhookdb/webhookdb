# frozen_string_literal: true

require "grape"

require "webhookdb/api"
require "webhookdb/replicator"

class Webhookdb::API::Services < Webhookdb::API::V1
  resource :services do
    route_param :service_name, type: String do
      get :fixtures do
        begin
          descr = Webhookdb::Replicator.registered!(params[:service_name])
        rescue Webhookdb::Replicator::Invalid
          merror!(403, "No service with that name exists.")
        end
        sint = Webhookdb::ServiceIntegration.new(
          service_name: params[:service_name],
          opaque_id: "svi_fixture",
          table_name: params[:service_name] + "_fixture",
        )
        sch = descr.ctor.call(sint).create_table_modification.to_s
        present({schema_sql: sch})
      end
    end
  end
end
