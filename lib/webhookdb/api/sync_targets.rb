# frozen_string_literal: true

require "webhookdb/api"
require "webhookdb/jobs/sync_target_run_sync"

class Webhookdb::API::SyncTargets < Webhookdb::API::V1
  resource :organizations do
    route_param :org_identifier, type: String do
      resource :sync_targets do
        helpers do
          valid_period = Webhookdb::SyncTarget.valid_period
          params :sync_target_params do
            optional :period_seconds,
                     type: Integer,
                     values: valid_period,
                     prompt: {
                       message: "How many seconds between syncs (#{valid_period.begin} to #{valid_period.end}):",
                       disable: ->(req) { req.path.end_with?("/update") },
                     }
            optional :schema,
                     type: String,
                     db_identifier: true,
                     allow_blank: true,
                     desc: "Schema (or namespace) to write the table into. Default to no schema/namespace."
            optional :table,
                     type: String,
                     db_identifier: true,
                     allow_blank: true,
                     desc: "Table to create and update. Default to match the table name of the service integration."
          end
        end

        get do
          org = lookup_org!
          subs = org.all_sync_targets
          message = ""
          if subs.empty?
            message = "Organization #{org.name} has no sync targets set up.\n" \
                      "Use `webhookdb sync create` to set up reflection from WebhookDB to your data source."
          end
          status 200
          present_collection subs, with: Webhookdb::API::SyncTargetEntity, message:
        end

        params do
          optional :connection_url,
                   prompt: "Enter the connection string for the database that WebhookDB should sync data to:"
          optional :service_integration_opaque_id,
                   type: String, allow_blank: false,
                   desc: "This is a deprecated parameter. In the future, please use `service_integration_identifier`."
          optional :service_integration_identifier, type: String, allow_blank: false
          use :sync_target_params
          at_least_one_of :service_integration_opaque_id, :service_integration_identifier
        end
        post :create do
          customer = current_customer
          org = lookup_org!(customer:)
          ensure_admin!(org, customer:)
          identifier = params[:service_integration_identifier] || params[:service_integration_opaque_id]
          sint = lookup_service_integration!(org, identifier)

          begin
            Webhookdb::DBAdapter.adapter(params[:connection_url])
          rescue Webhookdb::DBAdapter::UnsupportedAdapter => e
            invalid!(
              e.message,
              message: "The connection URL is not supported. #{Webhookdb::DBAdapter.supported_adapters_message}",
            )
          end

          stgt = Webhookdb::SyncTarget.create(
            service_integration: sint,
            connection_url: params[:connection_url],
            period_seconds: params[:period_seconds],
            schema: params[:schema] || "",
            table: params[:table] || "",
            created_by: customer,
          )
          message = "Every #{stgt.period_seconds} seconds, data from #{sint.service_name} "\
                    "in #{sint.table_name} will be reflected to #{stgt.displaysafe_connection_url}"
          status 200
          present stgt, with: Webhookdb::API::SyncTargetEntity, message:
        end

        route_param :opaque_id do
          helpers do
            def lookup!
              org = lookup_org!
              ensure_admin!(org)
              (stgt = org.all_sync_targets_dataset[opaque_id: params[:opaque_id]])
              merror!(403, "There is no sync target with that id.") if stgt.nil?
              return stgt
            end
          end
          params do
            optional :user, type: String, prompt: "Username for the connection:"
            optional :password, type: String, prompt: "Password for the connection:"
          end
          post :update_credentials do
            stgt = lookup!
            uri = URI(stgt.connection_url)
            uri.user = params[:user]
            uri.password = params[:password]
            stgt.update(connection_url: uri.to_s)
            status 200
            present stgt, with: Webhookdb::API::SyncTargetEntity, message: "Connection URL has been updated."
          end

          params do
            use :sync_target_params
          end
          post :update do
            stgt = lookup!
            stgt.period_seconds = params[:period_seconds] if params.key?(:period_seconds)
            stgt.table = params[:table] if params.key?(:table)
            stgt.schema = params[:schema] if params.key?(:schema)
            save_or_error!(stgt)
            status 200
            present stgt, with: Webhookdb::API::SyncTargetEntity, message: "Sync target has been updated."
          end

          params do
            optional :confirm, type: String
          end
          post :delete do
            stgt = lookup!
            if stgt.table != params[:confirm]&.strip
              Webhookdb::API::Helpers.prompt_for_required_param!(
                request,
                :confirm,
                "Please confirm your deletion by entering the sync target's table name '#{stgt.table}'. ",
              )
            end

            stgt.logger.warn("destroying_sync_target", customer_id: current_customer.id)
            stgt.destroy
            status 200
            message = "Sync target has been removed and will no longer sync."
            present stgt, with: Webhookdb::API::SyncTargetEntity, message:
          end

          post :sync do
            stgt = lookup!
            status 200
            next_sync = stgt.next_possible_sync(now: Time.now)
            Webhookdb::Jobs::SyncTargetRunSync.perform_at(next_sync, stgt.id)
            message = "Sync has been scheduled. It should start at about #{next_sync}."
            present stgt, with: Webhookdb::API::SyncTargetEntity, message:
          end
        end
      end
    end
  end
end
