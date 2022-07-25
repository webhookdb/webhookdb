# frozen_string_literal: true

require "grape"

require "webhookdb/api"
require "webhookdb/formatting"
require "webhookdb/async/audit_logger"
require "webhookdb/jobs/process_webhook"

class Webhookdb::API::ServiceIntegrations < Webhookdb::API::V1
  resource :service_integrations do
    route_param :opaque_id do
      helpers do
        def lookup_unauthed!
          sint = Webhookdb::ServiceIntegration[opaque_id: params[:opaque_id]]
          merror!(400, "No integration with that id") if sint.nil?
          return sint
        end

        def log_webhook(sint, sstatus)
          # Status can be set from:
          # - the 'status' method, which will be 201 if it hasn't been set,
          # or another value if it has been set.
          # - the webhook responder, which could respond with 401, etc
          # - if there was an exception- so no status is set yet- use 0
          # The main thing to watch out for is that we:
          # - Cannot assume an exception is a 500 (it can be rescued later)
          # - Must handle error! calls
          # Anyway, this is all pretty confusing, but it's all tested.
          rstatus = status == 201 ? (sstatus || 0) : status
          request.body.rewind
          Webhookdb::LoggedWebhook.dataset.insert(
            request_body: request.body.read,
            request_headers: request.headers.to_json,
            response_status: rstatus,
            organization_id: sint&.organization_id,
            service_integration_opaque_id: params[:opaque_id],
          )
        end
      end

      # this particular url (`v1/service_integrations/#{opaque_id}`) is not used by the CLI-
      # it is the url that customers should point their webhooks to.
      # we can't check org permissions on this endpoint
      # because external services will be posting webhooks here
      # hence, it has a special lookup function
      post do
        sint = lookup_unauthed!
        svc = Webhookdb::Services.service_instance(sint)
        whresp = svc.webhook_response(request)
        s_status, s_headers, s_body = whresp.to_rack

        if s_status >= 400
          logger.warn "rejected_webhook", webhook_headers: request.headers.to_h,
                                          webhook_body: env["api.request.body"]
          header "Whdb-Rejected-Reason", whresp.reason
        else
          event_json = Webhookdb::Event.create(
            "webhookdb.serviceintegration.webhook",
            [sint.id, {headers: request.headers, body: env["api.request.body"]}],
          ).as_json
          # Audit Log this synchronously.
          # It should be fast enough. We may as well log here so we can avoid
          # serializing the (large) webhook payload multiple times, as with normal pubsub.
          Webhookdb::Async::AuditLogger.new.perform(event_json)
          queue = svc.upsert_has_deps? ? "netout" : "webhook"
          Webhookdb::Jobs::ProcessWebhook.set(queue:).perform_async(event_json)
        end

        s_headers.each { |k, v| header k, v }
        if s_headers["Content-Type"] == "application/json"
          body JSON.parse(s_body)
        else
          env["api.format"] = :binary
          body s_body
        end
        status s_status
      ensure
        log_webhook(sint, s_status)
      end
    end
  end

  resource :organizations do
    route_param :org_identifier, type: String do
      resource :service_integrations do
        desc "Return all integrations associated with the organization."
        get do
          integrations = lookup_org!.service_integrations
          message = ""
          if integrations.empty?
            message = "This organization doesn't have any integrations set up yet.\n" \
                      "Use `webhookdb services list` and `webhookdb integrations create` to set one up."
          end
          present_collection integrations, with: Webhookdb::API::ServiceIntegrationEntity, message:
        end

        resource :create do
          helpers do
            def create_integration(org, name)
              available_services_list = org.available_service_names.join("\n\t")

              # If provided service name is invalid
              if Webhookdb::Services.registered_service(name).nil?
                step = Webhookdb::Services::StateMachineStep.new
                step.needs_input = false
                step.output =
                  %(
WebhookDB doesn't support a service called '#{name}.' These are all the services
currently supported by WebhookDB:

\t#{available_services_list}

You can run `webhookdb services list` at any time to see our list of available services.
                    )
                step.complete = true
                return step
              end

              # If org does not have access to the given service
              unless org.available_service_names.include?(name)
                step = Webhookdb::Services::StateMachineStep.new
                step.needs_input = false
                step.output =
                  %(
Your organization does not have permission to view the service called '#{name}.' These are all the services
you currently have access to:

\t#{available_services_list}

You can run `webhookdb services list` at any time to see the list of services available to your organization.
If the list does not look correct, you can contact support at #{Webhookdb.support_email}.
                    )
                # maybe include a support email to contact? i'd want to add the support email as a config var
                step.complete = true
                return step
              end
              sint = Webhookdb::ServiceIntegration.create(
                organization: org,
                table_name: (name + "_#{SecureRandom.hex(2)}"),
                service_name: name,
              )
              return sint.calculate_create_state_machine
            end

            def verify_unique_integration(org)
              return if Webhookdb::ServiceIntegration.where(
                organization: org,
                service_name: params[:service_name],
              ).all.empty?
              return if params.key?(:guard_confirm)
              Webhookdb::API::Helpers.prompt_for_required_param!(
                request,
                :guard_confirm,
                "WARNING: #{org.name} already has an integration for service #{params[:service_name]}. " \
                "Press Enter to create another, or Ctrl+C to quit:",
              )
            end
          end
          desc "Create service integration on a given organization"
          params do
            optional :service_name, type: String,
                                    prompt: "Enter the name of the service to create an integration for. " \
                                            "Run 'webhookdb services list' to see available services:"
            optional :guard_confirm
          end
          post do
            customer = current_customer
            org = lookup_org!
            merror!(402, "You have reached the maximum number of free integrations") unless org.can_add_new_integration?
            ensure_admin!
            verify_unique_integration(org)
            customer.db.transaction do
              state_machine = create_integration(org, params[:service_name])
              status 200
              present state_machine, with: Webhookdb::API::StateMachineEntity
            end
          end
        end

        route_param :sint_identifier, type: String do
          helpers do
            def ensure_plan_supports!
              org = lookup_org!
              sint = lookup_service_integration!(org, params[:sint_identifier])
              err_msg = "Integration no longer supported--please visit website to activate subscription."
              merror!(402, err_msg) unless sint.plan_supports_integration?
            end
          end

          post :reset do
            ensure_plan_supports!
            c = current_customer
            org = lookup_org!
            sint = lookup_service_integration!(org, params[:sint_identifier])
            svc = Webhookdb::Services.service_instance(sint)
            merror!(403, "Sorry, you cannot modify this integration.") unless sint.can_be_modified_by?(c)
            svc.clear_create_information
            state_machine = svc.calculate_create_state_machine
            status 200
            present state_machine, with: Webhookdb::API::StateMachineEntity
          end

          post :upsert do
            current_customer
            org = lookup_org!
            sint = lookup_service_integration!(org, params[:sint_identifier])
            svc = Webhookdb::Services.service_instance(sint)
            body = env["api.request.body"]
            begin
              svc.upsert_webhook(body:)
            rescue KeyError, TypeError => e
              self.logger.error "immediate_upsert", error: e
              err_msg = "Sorry! Looks like something has gone wrong. " \
                        "Check your schema or contact support at #{Webhookdb.support_email}."
              merror!(400, err_msg)
            end
            status 200
            present({}, with: Webhookdb::API::BaseEntity, message: "You have upserted into #{sint.table_name}.")
          end

          resource :backfill do
            post do
              ensure_plan_supports!
              c = current_customer
              org = lookup_org!
              sint = lookup_service_integration!(org, params[:sint_identifier])
              svc = Webhookdb::Services.service_instance(sint)
              merror!(403, "Sorry, you cannot modify this integration.") unless sint.can_be_modified_by?(c)
              state_machine = svc.calculate_backfill_state_machine
              if state_machine.complete
                Webhookdb.publish(
                  "webhookdb.serviceintegration.backfill", sint.id,
                )
              end
              status 200
              present state_machine, with: Webhookdb::API::StateMachineEntity
            end

            post :reset do
              ensure_plan_supports!
              c = current_customer
              org = lookup_org!
              sint = lookup_service_integration!(org, params[:sint_identifier])
              svc = Webhookdb::Services.service_instance(sint)
              merror!(403, "Sorry, you cannot modify this integration.") unless sint.can_be_modified_by?(c)
              svc.clear_backfill_information
              state_machine = svc.calculate_backfill_state_machine
              status 200
              present state_machine, with: Webhookdb::API::StateMachineEntity
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
                org = lookup_org!
                sint = lookup_service_integration!(org, params[:sint_identifier])
                merror!(403, "Sorry, you cannot modify this integration.") unless sint.can_be_modified_by?(c)
                state_machine = sint.process_state_change(params[:field], params[:value])
                status 200
                present state_machine, with: Webhookdb::API::StateMachineEntity
              end
            end
          end

          desc "Gets stats about webhooks for this service integration."
          get :stats do
            org = lookup_org!
            sint = lookup_service_integration!(org, params[:sint_identifier])
            stats = sint.stats
            status 200
            present stats.as_json
          end

          params do
            optional :confirm, type: String
          end
          post :delete do
            ensure_plan_supports!
            ensure_admin!
            org = lookup_org!
            sint = lookup_service_integration!(org, params[:sint_identifier])
            if sint.table_name != params[:confirm]&.strip
              Webhookdb::API::Helpers.prompt_for_required_param!(
                request,
                :confirm,
                "Please confirm your deletion by entering the integration's table name '#{sint.table_name}'. " \
                "The table and all data for this integration will also be removed:",
              )
            end

            begin
              sint.service_instance.admin_dataset(timeout: :fast) { |ds| ds.db << "DROP TABLE #{sint.table_name}" }
            rescue Sequel::DatabaseError => e
              raise unless e.wrapped_exception.is_a?(PG::UndefinedTable)
            end
            sint.destroy
            message = "Great! We've deleted all secrets for #{sint.service_name}. " \
                      "The table #{sint.table_name} containing its data has been dropped."
            status 200
            present sint, with: Webhookdb::API::ServiceIntegrationEntity, message:
          end

          params do
            optional :new_name,
                     type: String,
                     db_identifier: true,
                     prompt: "Enter the new name of the table. " + Webhookdb::DBAdapter::INVALID_IDENTIFIER_MESSAGE
          end
          post :rename_table do
            org = lookup_org!
            sint = lookup_service_integration!(org, params[:sint_identifier])
            ensure_admin!
            old_name = sint.table_name
            sint.db.transaction do
              sint.rename_table(to: params[:new_name])
              message = "The table for #{sint.service_name} has been renamed from #{old_name} to #{sint.table_name}."
              status 200
              present sint, with: Webhookdb::API::ServiceIntegrationEntity, message:
            end
          end
        end
      end
    end
  end
end
