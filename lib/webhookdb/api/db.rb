# frozen_string_literal: true

require "grape"

require "webhookdb/api"
require "webhookdb/services"

class Webhookdb::API::Db < Webhookdb::API::V1
  resource :db do
    route_param :org_identifier, type: String do
      desc "Returns the connection string"
      get :connection do
        _customer = current_customer
        org = lookup_org!
        r = {connection_url: org.readonly_connection_url}
        present r
      end

      desc "Returns a list of all tables in the organization's db."
      get :tables do
        _customer = current_customer
        org = lookup_org!
        tables = Webhookdb::ConnectionCache.borrow(org.readonly_connection_url_raw, &:tables)
        message = ""
        if tables.empty?
          message = "You have not set up any service integrations.\n" \
                    "Use `webhookdb services list` and `webhookdb integrations create` to get started."
        end
        present({tables:, message:})
      end

      desc "Execute an arbitrary query against an org's connection string"
      params do
        requires :query, type: String, allow_blank: false, prompt: "Input your SQL query, and then press Enter:"
      end
      post :sql do
        _customer = current_customer
        org = lookup_org!
        begin
          r = org.execute_readonly_query(params[:query])
        rescue Sequel::DatabaseError => e
          self.logger.error("db_query_database_error", error: e)
          merror!(403, "You do not have permission to perform this query. Queries must be read-only.")
        end
        status 200
        present({rows: r.rows, headers: r.columns, max_rows_reached: r.max_rows_reached})
      end

      params do
        requires :guard_confirm,
                 prompt: [
                   "WARNING: This will invalid your existing database credentials. " \
                   "Enter to proceed, or Ctrl+C to quit:",
                   ->(v) { !v.nil? },
                 ]
      end
      post :roll_credentials do
        ensure_admin!
        org = lookup_org!
        org.roll_database_credentials
        connection_url = org.readonly_connection_url
        status 200
        present(
          {connection_url:},
          with: Webhookdb::API::BaseEntity,
          message: "Your database connection string is now: #{connection_url}",
        )
      end

      params do
        optional :message_fdw, type: Boolean
        optional :message_views, type: Boolean
        optional :message_all, type: Boolean
        requires :remote_server_name, type: String
        requires :fetch_size, type: String
        requires :local_schema, type: String
        requires :view_schema, type: String
      end
      post :fdw do
        org = lookup_org!
        resp = Webhookdb::Organization::DbBuilder.new(org).generate_fdw_payload(
          remote_server_name: params[:remote_server_name],
          fetch_size: params[:fetch_size],
          local_schema: params[:local_schema],
          view_schema: params[:view_schema],
        )
        resp[:message] = if params[:message_fdw]
                           resp[:fdw_sql]
        elsif params[:message_views]
          resp[:views_sql]
        else
          resp[:compound_sql]
        end
        status 200
        present resp
      end
    end
  end
end
