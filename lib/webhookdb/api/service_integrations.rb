# frozen_string_literal: true

require "grape"

require "webhookdb/api"
require "webhookdb/aws"

class Webhookdb::API::ServiceIntegrations < Webhookdb::API::V1
  # this particular url (`v1/service_integrations/#{opaque_id}`) is not used by the CLI-
  # it is the url that customers should point their webhooks to
  resource :service_integrations do
    route_param :opaque_id, type: String do
      helpers do
        def lookup!
          sint = Webhookdb::ServiceIntegration[opaque_id: params[:opaque_id]]
          merror!(400, "No integration with that id") if sint.nil? || sint.soft_deleted?
          return sint
        end

        def ensure_plan_supports!
          sint = lookup!
          err_msg = "Integration no longer supported--please visit website to activate subscription."
          merror!(402, err_msg) unless sint.plan_supports_integration?
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

      resource :reset do
        post do
          ensure_plan_supports!
          c = current_customer
          sint = lookup!
          svc = Webhookdb::Services.service_instance(sint)
          merror!(403, "Sorry, you cannot modify this integration.") unless sint.can_be_modified_by?(c)
          svc.clear_create_information
          state_machine = svc.calculate_create_state_machine
          status 200
          present state_machine, with: Webhookdb::API::StateMachineEntity
        end
      end

      resource :backfill do
        post do
          ensure_plan_supports!
          c = current_customer
          sint = lookup!
          svc = Webhookdb::Services.service_instance(sint)
          merror!(403, "Sorry, you cannot modify this integration.") unless sint.can_be_modified_by?(c)
          state_machine = svc.calculate_backfill_state_machine
          if state_machine.complete == true
            Webhookdb.publish(
              "webhookdb.serviceintegration.backfill", sint.id,
            )
          end
          status 200
          present state_machine, with: Webhookdb::API::StateMachineEntity
        end

        resource :reset do
          post do
            ensure_plan_supports!
            c = current_customer
            sint = lookup!
            svc = Webhookdb::Services.service_instance(sint)
            merror!(403, "Sorry, you cannot modify this integration.") unless sint.can_be_modified_by?(c)
            svc.clear_backfill_information
            state_machine = svc.calculate_backfill_state_machine
            status 200
            present state_machine, with: Webhookdb::API::StateMachineEntity
          end
        end
      end

      resource :transition do
        route_param :field do
          params do
            requires :value
          end
          post do
            ensure_plan_supports!
            c = current_customer
            sint = lookup!
            merror!(403, "Sorry, you cannot modify this integration.") unless sint.can_be_modified_by?(c)
            state_machine = sint.process_state_change(params[:field], params[:value])
            status 200
            present state_machine, with: Webhookdb::API::StateMachineEntity
          end
        end
      end
    end
  end
end
