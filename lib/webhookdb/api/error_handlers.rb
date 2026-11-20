# frozen_string_literal: true

require "webhookdb/api"

class Webhookdb::API::ErrorHandlers < Webhookdb::API::V1
  include Webhookdb::Service::Types

  CREATE_PROMPT = "What is the URL that WebhookDB should POST to when a replicator fails? " \
                  "See #{Webhookdb::Organization::ErrorHandler::DOCS_URL} for more information:".freeze

  resource :organizations do
    route_param :org_identifier do
      resource :error_handlers do
        helpers do
          def lookup!
            org = lookup_org!
            eh = org.error_handlers_dataset[opaque_id: params[:opaque_id].strip]
            merror!(403, "There is no error handler with that id.") if eh.nil?
            set_request_tags(error_handler_opaque_id: eh.opaque_id)
            return eh
          end

          def guard_editable!(customer, org)
            return if has_admin?(org, customer:)
            permission_error!("You must be an org admin to modify error handlers.")
          end

          def url_valid?(u)
            begin
              uri = URI(u)
            rescue URI::InvalidURIError
              return false
            end
            return true if uri.scheme == "sentry"
            return false unless uri.scheme&.start_with?("http")
            return true
          end
        end

        desc "Returns a list of all error handlers associated with the org."
        get do
          handlers = lookup_org!.error_handlers
          message = ""
          if handlers.empty?
            message = "This organization doesn't have any error handlers yet.\n" \
                      "Use `webhookdb error-handler create` to set one up."
          end
          present_collection handlers, with: ErrorHandlerEntity, message:
        end

        desc "Creates a new error handler."
        params do
          optional :url, type: TrimmedString, prompt: CREATE_PROMPT
        end
        post :create do
          cust = current_customer
          org = lookup_org!
          guard_editable!(cust, org)
          unless url_valid?(params[:url])
            msg = "URL is malformed. It should be a URL like https://foo.bar/path, http://foo.bar:123, etc. " \
                  "See #{Webhookdb::Organization::ErrorHandler::DOCS_URL} for more info."
            merror!(400, msg)
          end
          eh = Webhookdb::Organization::ErrorHandler.create(
            organization: org,
            url: params[:url],
            created_by: cust,
          )
          message = "Whenever one of your replicators errors, WebhookDB will alert the given URL. " \
                    "See #{Webhookdb::Organization::ErrorHandler::DOCS_URL} for more information."
          status 200
          present eh, with: ErrorHandlerEntity, message:
        end

        route_param :opaque_id, type: String do
          get do
            eh = lookup!
            status 200
            present eh, with: ErrorHandlerEntity
          end

          post :delete do
            customer = current_customer
            eh = lookup!
            guard_editable!(customer, eh.organization)
            eh.destroy
            status 200
            present eh, with: ErrorHandlerEntity,
                        message: "You have successfully deleted the error handler '#{eh.opaque_id}'."
          end
        end
      end
    end
  end

  class ErrorHandlerEntity < Webhookdb::API::BaseEntity
    expose :opaque_id, as: :id
    expose :url

    def self.display_headers
      return [[:id, "ID"], [:url, "Url"]]
    end
  end
end
