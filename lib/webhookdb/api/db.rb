# frozen_string_literal: true

require "grape"

require "webhookdb/api"
require "webhookdb/services"

class Webhookdb::API::Db < Webhookdb::API::V1
  resource :db do
    route_param :identifier, type: String do
      desc "Returns a list of all tables in the organization's db."
      get do
        _customer = current_customer
        org = lookup_org!
        r = Webhookdb::ConnectionCache.borrow(org.readonly_connection_url) do |conn|
          {tables: conn.tables}
        end
        present r
      end

      resource :sql do
        desc "Execute an arbitrary query against an org's connection string"
        params do
          requires :query, type: String, allow_blank: false
        end
        post do
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
      end
    end
  end
end
