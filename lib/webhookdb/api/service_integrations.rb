# frozen_string_literal: true

require "grape"

require "webhookdb/api"
require "webhookdb/aws"

class Webhookdb::API::ServiceIntegrations < Webhookdb::API::V1
  resource :service_integrations do
    desc "Return all integrations associated with organization"
    params do
      requires :organization_id, type: String
    end
    get do
      org = Webhookdb::Organization[params[:organization_id]]
      data = org.service_integrations
      if data.empty?
        present({}, with: Webhookdb::AdminAPI::BaseEntity,
                    message: "Organization doesn't have any integrations yet.",)
      else
        present data, with: Webhookdb::AdminAPI::ServiceIntegrationEntity
      end
    end

    # this particular url (`v1/service_integrations/#{opaque_id}`) is not used by the CLI-
    # it is the url that customers should point their webhooks to

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
