# frozen_string_literal: true

require "grape"
require "oj"

require "webhookdb/api"
require "webhookdb/formatting"
require "webhookdb/replicator"
require "webhookdb/async/audit_logger"
require "webhookdb/jobs/process_webhook"

class Webhookdb::API::ServiceIntegrations < Webhookdb::API::V1
  # These URLs are not used by the CLI-
  # they are the url that customers should point their webhooks to.
  # We can't check org permissions on this endpoint
  # because external services (so no auth) will be posting webhooks here.
  # So, we have a special lookup function, and depend on webhook verification
  # to ensure the request is valid.
  resource :service_integrations do
    helpers do
      def lookup_unauthed!(opaque_id)
        sint = Webhookdb::ServiceIntegration[opaque_id:]
        merror!(400, "No integration with that id") if sint.nil?
        return sint
      end

      def log_webhook(opaque_id, organization_id, sstatus, request_headers)
        return if request.headers[Webhookdb::LoggedWebhook::RETRY_HEADER]
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
          request_headers: request_headers.to_json,
          request_method: request.request_method,
          request_path: request.path_info,
          response_status: rstatus,
          organization_id:,
          service_integration_opaque_id: opaque_id,
        )
      end
    end

    route [:post, :put, :delete, :patch], "/:opaque_id*" do
      request_headers = request.headers.dup
      if (content_type = env["CONTENT_TYPE"])
        request_headers["Content-Type"] = content_type
      end
      sint = lookup_unauthed!(params[:opaque_id])
      svc = Webhookdb::Replicator.create(sint).dispatch_request_to(request)
      svc.preprocess_headers_for_logging(request_headers)
      handling_sint = svc.service_integration
      whresp = svc.webhook_response(request)
      s_status, s_headers, s_body = whresp.to_rack
      (s_status = 200) if s_status >= 400 && Webhookdb.regression_mode?

      if s_status >= 400
        logger.warn "rejected_webhook", webhook_headers: request_headers,
                                        webhook_body: env["api.request.body"]
        header "Whdb-Rejected-Reason", whresp.reason
      else
        req_body = env.key?("api.request.body") ? env["api.request.body"] : env["rack.input"].read
        req_body = {} if req_body.blank?
        process_kwargs = {
          headers: request_headers,
          body: req_body || {},
          request_path: request.path_info,
          request_method: request.request_method,
        }
        event_json = Amigo::Event.create(
          "webhookdb.serviceintegration.webhook", [handling_sint.id, process_kwargs],
        ).as_json
        # Audit Log this synchronously.
        # It should be fast enough. We may as well log here so we can avoid
        # serializing the (large) webhook payload multiple times, as with normal pubsub.
        Webhookdb::Async::AuditLogger.new.perform(event_json)
        if svc.process_webhooks_synchronously? || Webhookdb::Replicator.always_process_synchronously
          whreq = Webhookdb::Replicator::WebhookRequest.new(
            method: process_kwargs[:request_method],
            path: process_kwargs[:request_path],
            headers: process_kwargs[:headers],
            body: process_kwargs[:body],
          )
          inserted = svc.upsert_webhook(whreq)
          s_body = svc.synchronous_processing_response_body(upserted: inserted, request: whreq)
        else
          queue = svc.upsert_has_deps? ? "netout" : "webhook"
          Webhookdb::Jobs::ProcessWebhook.set(queue:).perform_async(event_json)
        end
      end

      s_headers.each { |k, v| header k, v }
      if s_headers["Content-Type"] == "application/json"
        body Oj.load(s_body)
      else
        env["api.format"] = :binary
        body s_body
      end
      status s_status
    ensure
      log_webhook(params[:opaque_id], sint&.organization_id, s_status, request_headers)
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
              available_services_list = org.available_replicator_names.sort.join("\n\t")

              service_name_invalid = Webhookdb::Replicator.registered(name).nil?
              if service_name_invalid
                message = %(WebhookDB doesn't support a service called '#{name}.'
These are all the services currently supported by WebhookDB:

\t#{available_services_list}

Run `webhookdb services list` to see available services, and try again with the new name.)
                merror!(400, message, code: "invalid_service", alert: true)
              end

              # If org does not have access to the given service
              unless org.available_replicator_names.include?(name)
                step = Webhookdb::Replicator::StateMachineStep.new
                step.needs_input = false
                step.output =
                  %(
Your organization does not have permission to view the service called '#{name}.' These are all the services
you currently have access to:

\t#{available_services_list}

You can run `webhookdb services list` at any time to see the list of services available to your organization.
If the list does not look correct, you can contact support at #{Webhookdb.support_email}.)
                step.complete = true
                return step
              end
              sint = Webhookdb::ServiceIntegration.create_disambiguated(name, organization: org)
              replicator = sint.replicator
              # We always want to enqueue the backfill job if it is possible to do so, even if
              # we are not returning the backfill step in our response to this create request
              if replicator.descriptor.supports_backfill?
                backfill_step, _job = replicator.calculate_and_backfill_state_machine(incremental: true)
              end

              # Prefer creating using webhooks, not backfilling, but fall back to backfilling.
              return replicator.calculate_webhook_state_machine if replicator.descriptor.supports_webhooks?
              return backfill_step
            end

            def verify_unique_integration(org)
              existing = Webhookdb::ServiceIntegration.where(
                organization: org,
                service_name: params[:service_name],
              ).first
              return if existing.nil?
              return if params.key?(:guard_confirm)
              Webhookdb::API::Helpers.prompt_for_required_param!(
                request,
                :guard_confirm,
                "WARNING: #{org.name} already has an integration for service #{params[:service_name]}.\n" \
                "Press Enter to create another, or Ctrl+C to quit.\n" \
                "Modify the existing integration using `webhookdb integrations #{existing.opaque_id} setup`",
              )
            end
          end
          desc "Create service integration on a given organization"
          params do
            optional :service_name, type: String,
                                    prompt: "Enter the name of the service to create an integration for.\n" \
                                            "Run 'webhookdb services list' to see available services:"
            optional :guard_confirm
          end
          post do
            customer = current_customer
            org = lookup_org!
            merror!(402, "You have reached the maximum number of free integrations", alert: true) unless
              org.can_add_new_integration?
            ensure_admin!
            verify_unique_integration(org)
            step = nil
            customer.db.transaction do
              step = create_integration(org, params[:service_name])
              # No reason to create the integration when this happens.
              # We may want to expand the situations we roll back,
              # but we start by being targeted.
              raise Sequel::Rollback if step.error_code == "no_candidate_dependency"
            end
            status 200
            present step, with: Webhookdb::API::StateMachineEntity
          end
        end

        route_param :sint_identifier, type: String do
          helpers do
            def ensure_plan_supports!(org=nil)
              org ||= lookup_org!
              sint = lookup_service_integration!(org, params[:sint_identifier])
              return if sint.plan_supports_integration?
              err_msg = "This integration is no longer supported. " \
                        "Run `webhookdb subscription edit` to manage your subscription."
              merror!(402, err_msg, alert: true)
            end

            def ensure_can_be_modified!(sint, c)
              permission_error!("Sorry, you cannot modify this integration.") unless sint.can_be_modified_by?(c)
            end
          end

          post :setup do
            ensure_plan_supports!
            c = current_customer
            org = lookup_org!
            sint = lookup_service_integration!(org, params[:sint_identifier])
            svc = Webhookdb::Replicator.create(sint)
            merror!(403, "Sorry, you cannot modify this integration.") unless sint.can_be_modified_by?(c)
            state_machine = svc.calculate_preferred_create_state_machine
            status 200
            present state_machine, with: Webhookdb::API::StateMachineEntity
          end

          post :reset do
            ensure_plan_supports!
            c = current_customer
            org = lookup_org!
            sint = lookup_service_integration!(org, params[:sint_identifier])
            svc = Webhookdb::Replicator.create(sint)
            merror!(403, "Sorry, you cannot modify this integration.") unless sint.can_be_modified_by?(c)
            svc.clear_webhook_information
            state_machine = svc.calculate_preferred_create_state_machine
            status 200
            present state_machine, with: Webhookdb::API::StateMachineEntity
          end

          post :upsert do
            current_customer
            org = lookup_org!
            sint = lookup_service_integration!(org, params[:sint_identifier])
            svc = Webhookdb::Replicator.create(sint)
            body = env["api.request.body"]
            begin
              svc.upsert_webhook_body(body)
            rescue KeyError, TypeError => e
              self.logger.error "immediate_upsert", error: e
              err_msg = "Sorry! Looks like something has gone wrong. " \
                        "Check your schema or contact support at #{Webhookdb.support_email}."
              merror!(400, err_msg)
            end
            status 200
            present({}, with: Webhookdb::API::BaseEntity, message: "You have upserted into #{sint.table_name}.")
          end

          desc "Returns information about the integration."
          params do
            optional :field, type: String, values: Webhookdb::ServiceIntegration::INTEGRATION_INFO_FIELDS
          end
          post :info do
            ensure_plan_supports!
            org = lookup_org!
            sint = lookup_service_integration!(org, params[:sint_identifier])
            data = {
              id: sint.opaque_id,
              service: sint.service_name,
              table: sint.table_name,
              url: sint.replicator.webhook_endpoint,
              webhook_secret: sint.webhook_secret,
            }

            field_name = params[:field]
            blocks = Webhookdb::Formatting.blocks
            if field_name.present?
              blocks.line(data.fetch(field_name.to_sym))
            else
              rows = data.map do |k, v|
                [k.to_s.capitalize, v]
              end
              blocks.table(["Field", "Value"], rows)
            end
            r = {blocks: blocks.as_json}
            status 200
            present r
          end

          resource :backfill do
            helpers do
              def lookup_backfillable_replicator(customer:, allow_connstr_auth: false)
                org = lookup_org!(allow_connstr_auth:)
                ensure_plan_supports!(org)
                sint = lookup_service_integration!(org, params[:sint_identifier])
                ensure_can_be_modified!(sint, customer) if customer
                return sint.replicator
              end

              def ensure_backfill_supported!(rep)
                return if rep.descriptor.supports_backfill?
                msg = rep.backfill_not_supported_message
                merror!(409, msg)
              end
            end

            params do
              optional :incremental, type: Boolean
            end
            post do
              rep = lookup_backfillable_replicator(customer: current_customer)
              ensure_backfill_supported!(rep)
              state_machine, _ = rep.calculate_and_backfill_state_machine(incremental: params.fetch(:incremental, true))
              status 200
              present state_machine, with: Webhookdb::API::StateMachineEntity
            end

            post :reset do
              repl = lookup_backfillable_replicator(customer: current_customer)
              ensure_backfill_supported!(repl)
              state_machine = repl.service_integration.db.transaction do
                repl.clear_backfill_information
                step, _ = repl.calculate_and_backfill_state_machine(incremental: true)
                step
              end
              status 200
              present state_machine, with: Webhookdb::API::StateMachineEntity
            end

            resource :job do
              params do
                optional :incremental, type: Boolean, default: true
                optional :criteria, type: JSON
                optional :recursive, type: Boolean, default: true
                optional :synchronous, type: Boolean
              end
              post do
                rep = lookup_backfillable_replicator(customer: nil, allow_connstr_auth: true)
                ensure_backfill_supported!(rep)
                sint = rep.service_integration
                incremental = params.fetch(:incremental)
                recursive = params.fetch(:recursive)
                if (synchronous = params[:synchronous] || false)
                  invalid!("Recursive backfills cannot be synchronous") if recursive
                  invalid!("Only incremental backfills can be synchronous") unless incremental
                  unless sint.organization.priority_backfill
                    merror!(402,
                            "Organization does not support sychronous backfills",
                            code: "priority_backfill_not_enabled",)
                  end
                end
                _, job = rep.calculate_and_backfill_state_machine(
                  incremental:,
                  recursive:,
                  criteria: params[:criteria] || nil,
                  enqueue: !synchronous,
                )
                if job.nil?
                  msg = "Sorry, this integration is not set up to backfill. " \
                        "Run `webhookdb backfill #{sint.opaque_id}` to finish setup."
                  merror!(409, msg, code: "backfill_not_set_up")
                end
                sint.replicator.backfill(job) if synchronous
                status 200
                present job, with: Webhookdb::API::BackfillJobEntity
              end

              route_param :job_id, type: String do
                get do
                  org = lookup_org!(allow_connstr_auth: true)
                  job = Webhookdb::BackfillJob[service_integration: org.service_integrations_dataset,
                                               opaque_id: params[:job_id]]
                  forbidden! if job.nil?
                  present job, with: Webhookdb::API::BackfillJobEntity
                end
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
                org = lookup_org!
                sint = lookup_service_integration!(org, params[:sint_identifier])
                ensure_can_be_modified!(sint, c)
                state_machine = sint.replicator.process_state_change(params[:field], params[:value])
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
            dependents_lines = sint.recursive_dependents.map(&:table_name).join("\n")
            if sint.table_name != params[:confirm]&.strip
              output = if sint.dependents.empty?
                         "Please confirm your deletion by entering the integration's table name '" \
                           "#{sint.table_name}'. The table and all data for this integration will also be removed."
              else
                %(This integration has dependents and therefore cannot be deleted on its own.
If you choose to go forward with the deletion, WebhookDB will recursively delete all dependents.
For reference, this includes the following integrations:

#{dependents_lines}

Please confirm your deletion by entering the integration's table name '#{sint.table_name}'.
The tables and all data for this integration and its dependents will also be removed:)
                           end
              Webhookdb::API::Helpers.prompt_for_required_param!(
                request,
                :confirm,
                "Confirm table name '#{sint.table_name}':",
                output:,
              )
            end

            sint.destroy_self_and_all_dependents
            status 200

            if sint.dependents.empty?
              confirmation_msg = "Great! We've deleted all secrets for #{sint.service_name}. " \
                                 "The table #{sint.table_name} containing its data has been dropped."
          else
            confirmation_msg = "Great! We've deleted all secrets for #{sint.service_name} and its dependents. " \
                               "The following tables have been dropped: \n\n #{sint.table_name} \n #{dependents_lines}"
                               end
            present sint, with: Webhookdb::API::ServiceIntegrationEntity, message: confirmation_msg
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
