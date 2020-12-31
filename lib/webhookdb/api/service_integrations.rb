# frozen_string_literal: true

require "grape"

require "webhookdb/api"
require "webhookdb/aws"

class Webhookdb::API::ServiceIntegrations < Webhookdb::API::V1
  resource :service_integrations do
    route_param :opaque_id, type: String do
      helpers do
        def lookup!
          sint = Webhookdb::ServiceIntegration[opaque_id: params[:opaque_id]]
          merror!(400, "No integration with that id") if sint.nil? || sint.soft_deleted?
          return sint
        end
      end

      post do
        sint = lookup!
        svc = Webhookdb::Services.create_service(sint)
        sint.publish_immediate("webhook", sint.id, {headers: request.headers, body: env["api.request.body"]})
        env["api.format"] = :binary
        content_type svc.webhook_response_content_type
        svc.webhook_response_headers.each { |k, v| header k, v }
        body svc.webhook_response_body
        status 202
      end
    end
  end
end
