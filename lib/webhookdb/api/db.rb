# frozen_string_literal: true

require "grape"

require "webhookdb/api"
require "webhookdb/services"

class Webhookdb::API::Db < Webhookdb::API::V1
  resource :db do
    route_param :identifier, type: String do
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
        r = Webhookdb::ConnectionCache.borrow(org.readonly_connection_url_raw) do |conn|
          {tables: conn.tables}
        end
        present r
      end

      desc "Execute an arbitrary query against an org's connection string"
      params do
        requires :query, type: String, allow_blank: false
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
        present({rows: r.rows, columns: r.columns, max_rows_reached: r.max_rows_reached})
      end

      post :roll_credentials do
        ensure_admin!
        org = lookup_org!
        org.roll_database_credentials
        r = {connection_url: org.readonly_connection_url}
        status 200
        present r
      end
    end
  end
end
