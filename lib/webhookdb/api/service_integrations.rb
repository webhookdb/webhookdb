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
        svc = Webhookdb::Services.service_instance(sint)
        s_status, s_headers, s_body = svc.webhook_response(request)

        if s_status < 400
          sint.publish_immediate("webhook", sint.id, {headers: request.headers, body: env["api.request.body"]})
        end

        env["api.format"] = :binary
        s_headers.each { |k, v| header k, v }
        body s_body
        status s_status
      end
    end
  end
end
