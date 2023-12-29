# frozen_string_literal: true

require "webhookdb/api"
require "webhookdb/jobs/sync_target_run_sync"

# rubocop:disable Layout/LineLength
class Webhookdb::API::SyncTargets < Webhookdb::API::V1
  class ConnectionUrlType < Grape::Validations::Validators::Base
    def validate!(params)
      url = params[:connection_url]
      case @option
        when "db", "http"
          if (err = Webhookdb::SyncTarget.send(:"validate_#{@option}_url", url))
            raise Grape::Exceptions::Validation.new params: [url], message: err
          end
      else
          raise Grape::Exceptions::Validation.new params: [url], message: "#{@option} is not a valid connection url type"
      end
    end
  end

  resource :organizations do
    route_param :org_identifier, type: String do
      resource :sync_targets do
        [:db, :http].each do |target_type_resource|
          resource target_type_resource do
            route_setting :target_type, {key: target_type_resource}
            helpers do
              is_db = target_type_resource == :db
              def target_type
                tgttype = route.settings[:target_type]
                # Doesn't appear that this cascades, so we need to specify on every verb method.
                raise "add `route_setting :target_type, target_type_resource` before verb" unless tgttype
                return tgttype
              end

              def db? = target_type == :db

              default_period = Webhookdb::SyncTarget.default_valid_period
              params :sync_target_params do
                optional :period_seconds,
                         type: Integer,
                         values: Webhookdb::SyncTarget.valid_period(1),
                         prompt: {
                           message: "How many seconds between syncs (#{default_period.begin} to #{default_period.end}):",
                           disable: ->(req) { req.path.end_with?("/update") },
                         }
                is_db && optional(:schema,
                                  type: String,
                                  db_identifier: true,
                                  allow_blank: true,
                                  desc: "Schema (or namespace) to write the table into. Default to no schema/namespace.",)
                # The description here says there is a default value, but the default value isn't actually saved to the SyncTarget
                # object--it's inferred in the SyncTarget sync behavior when the table value is a blank string.
                is_db && optional(:table,
                                  type: String,
                                  db_identifier: true,
                                  allow_blank: true,
                                  desc: "Table to create and update. Default to match the table name of the service integration.",)
                !is_db && optional(:page_size,
                                   type: Integer,
                                   values: (1..1000),
                                   desc: "Maximum number of rows in each POST request.",)
              end
              params :connection_url do
                optional :connection_url,
                         type: String,
                         prompt: "Enter the #{is_db ? 'database connection string' : 'HTTP endpoint'} that WebhookDB should sync data to:",
                         connection_url_type: is_db ? "db" : "http"
              end

              def entity
                return db? ? Webhookdb::API::DbSyncTargetEntity : Webhookdb::API::HttpSyncTargetEntity
              end

              def validate_period!(org, value)
                r = Webhookdb::SyncTarget.valid_period_for(org)
                return if r.cover?(value)
                err = "The valid sync period for organization #{org.name} is between #{r.begin} and #{r.end} seconds."
                invalid!(err, message: err)
              end

              def verify_connection(url)
                if db?
                  Webhookdb::SyncTarget.verify_db_connection(url)
                else
                  Webhookdb::SyncTarget.verify_http_connection(url)
                end
              rescue Webhookdb::SyncTarget::InvalidConnection => e
                merror!(400, e.to_s, code: "invalid_sync_target_connection")
              end

              def predicate = db? ? :db? : :http?
              def fullname = db? ? "database" : "http"
              def cmd = db? ? "dbsync" : "httpsync"
              def tgtname = db? ? "database" : "endpoint"
            end

            route_setting :target_type, target_type_resource
            get do
              org = lookup_org!
              subs = org.all_sync_targets.filter(&predicate)
              message = ""
              if subs.empty?
                message = "Organization #{org.name} has no #{fullname} sync targets set up.\n" \
                          "Use `webhookdb #{cmd} create` to synchronization WebhookDB tables to your #{tgtname}."
              end
              status 200
              present_collection subs, with: entity, message:
            end

            params do
              use :connection_url
              use :sync_target_params
              optional :service_integration_opaque_id,
                       type: String, allow_blank: false,
                       desc: "This is a deprecated parameter. In the future, please use `service_integration_identifier`."
              optional :service_integration_identifier, type: String, allow_blank: false
              at_least_one_of :service_integration_opaque_id, :service_integration_identifier
            end
            route_setting :target_type, target_type_resource
            post :create do
              customer = current_customer
              org = lookup_org!(customer:)
              ensure_admin!(org, customer:)
              identifier = params[:service_integration_identifier] || params[:service_integration_opaque_id]
              sint = lookup_service_integration!(org, identifier)

              validate_period!(sint.organization, params[:period_seconds])
              verify_connection(params[:connection_url])
              stgt = Webhookdb::SyncTarget.create(
                service_integration: sint,
                connection_url: params[:connection_url],
                period_seconds: params[:period_seconds],
                schema: params[:schema] || "",
                table: params[:table] || "",
                page_size: params[:page_size],
                created_by: customer,
              )
              message = "Every #{stgt.period_seconds} seconds, data from #{sint.service_name} " \
                        "in #{sint.table_name} will be synchronized to #{stgt.displaysafe_connection_url}"
              status 200
              present stgt, with: entity, message:
            rescue Grape::Exceptions::Validation => e
              merror!(400, e.message)
            end

            route_param :opaque_id do
              helpers do
                def lookup!
                  org = lookup_org!
                  ensure_admin!(org)
                  (stgt = org.all_sync_targets_dataset[Sequel[:sync_targets][:opaque_id] => params[:opaque_id]])
                  merror!(403, "There is no #{fullname} sync target with that id.") if
                    stgt.nil? || !stgt.send(predicate)
                  return stgt
                end
              end
              params do
                optional :user, type: String, prompt: "Username for the connection:"
                optional :password, type: String, prompt: "Password for the connection:"
              end
              route_setting :target_type, target_type_resource
              post :update_credentials do
                stgt = lookup!
                uri = URI(stgt.connection_url)
                uri.user = params[:user]
                uri.password = params[:password]
                verify_connection(uri.to_s)
                stgt.update(connection_url: uri.to_s)
                status 200
                present stgt, with: entity, message: "Connection URL has been updated."
              end

              params do
                use :sync_target_params
              end
              route_setting :target_type, target_type_resource
              post :update do
                stgt = lookup!
                stgt.table = params[:table] if params.key?(:table)
                stgt.schema = params[:schema] if params.key?(:schema)
                stgt.page_size = params[:page_size] if params.key?(:page_size)
                if params.key?(:period_seconds) && (period_seconds = params[:period_seconds])
                  validate_period!(stgt.organization, period_seconds)
                  stgt.period_seconds = period_seconds
                end
                save_or_error!(stgt)
                status 200
                present stgt, with: entity, message: "#{fullname.capitalize} sync target has been updated."
              end

              params do
                optional :confirm, type: String
              end
              route_setting :target_type, target_type_resource
              post :delete do
                stgt = lookup!
                prompted_table = stgt.service_integration.table_name
                if prompted_table != params[:confirm]&.strip
                  Webhookdb::API::Helpers.prompt_for_required_param!(
                    request,
                    :confirm,
                    "Please confirm your deletion by entering the table name that is being synced by " \
                    "this #{fullname} sync target (#{prompted_table}):",
                  )
                end

                stgt.logger.warn("destroying_sync_target", sync_target_id: stgt.id, customer_id: current_customer.id)
                stgt.destroy
                status 200
                message = "#{fullname.capitalize} sync target has been removed and will no longer sync."
                present stgt, with: entity, message:
              end

              route_setting :target_type, target_type_resource
              post :sync do
                stgt = lookup!
                status 200
                next_sync = stgt.next_possible_sync(now: Time.now)
                Webhookdb::Jobs::SyncTargetRunSync.perform_at(next_sync, stgt.id)
                message = "#{fullname.capitalize} sync has been scheduled. It should start at about #{next_sync}."
                present stgt, with: entity, message:
              end
            end
          end
        end
      end
    end
  end
end
# rubocop:enable Layout/LineLength
