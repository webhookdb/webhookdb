# frozen_string_literal: true

require "grape"

require "webhookdb/api"
require "webhookdb/aws"

class Webhookdb::API::ServiceIntegrations < Webhookdb::API::V1
  resource :service_integrations do
    route_param :opaque_id, type: String do
      def lookup!; end

      post do
      end

      post :backfill do
      end
    end
  end
end
