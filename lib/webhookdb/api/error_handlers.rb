# frozen_string_literal: true

require "webhookdb/api"

class Webhookdb::API::ErrorHandlers < Webhookdb::API::V1
  include Webhookdb::Service::Types

  ALLOWED_SERVICES = Webhookdb::Organization::ErrorHandler::SERVICES

  resource :organizations do
    route_param :org_identifier do
      resource :error_handlers do
        helpers do
          def lookup!
            org = lookup_org!
            eh = org.error_handlers_dataset[opaque_id: params[:opaque_id].strip]
            merror!(403, "There is no error handler with that opaque_id.") if eh.nil?
            set_request_tags(error_handler_opaque_id: eh.opaque_id)
            return eh
          end

          def guard_editable!(customer, org)
            return if has_admin?(org, customer:)
            permission_error!("You must be an org admin to modify error handlers.")
          end
        end

        desc "Returns a list of all error handlers associated with the org."
        get do
          views = lookup_org!.error_handlers
          message = ""
          if views.empty?
            message = "This organization doesn't have any error handlers yet.\n" \
                      "Use `webhookdb error-handler create` to set one up."
          end
          present_collection views, with: ErrorHandlerEntity, message:
        end

        desc "Creates a new error handler."
        params do
          optional :service,
                   type: TrimmedString,
                   values: ALLOWED_SERVICES,
                   prompt: "How do you want to report errors (one of: #{ALLOWED_SERVICES.join(', ')}?"
        end
        post :create do
          cust = current_customer
          org = lookup_org!
          guard_editable!(cust, org)
          eh = Webhookdb::Organization::ErrorHandler.create(service: params[:service])
          step = eh.state_machine_step!
          status 200
          present step, with: Webhookdb::API::StateMachineEntity, message: step.message
        end

        route_param :opaque_id, type: String do
          resource :transition do
            route_param :field do
              params do
                requires :value
              end
              post do
                ensure_plan_supports!
                c = current_customer
                org = lookup_org!
                sint = lookup_service_integration!(org, params[:sint_identifier])
                ensure_can_be_modified!(sint, c)
                state_machine = sint.replicator.process_state_change(params[:field], params[:value])
                status 200
                present state_machine, with: Webhookdb::API::StateMachineEntity
              end
            end
          end

          post :delete do
            customer = current_customer
            eh = lookup!
            guard_editable!(customer, eh.organization)
            eh.destroy
            status 200
            present eh, with: ErrorHandlerEntity,
                        message: "You have successfully removed the error handler '#{eh.opaque_id}'."
          end
        end
      end
    end
  end

  class ErrorHandlerEntity < Webhookdb::API::BaseEntity
    expose :opaque_id
    expose :service

    def self.display_headers
      return [[:opaque_id, "Opaque ID"], [:service, "Service"]]
    end
  end
end
