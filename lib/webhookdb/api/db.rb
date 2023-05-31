# frozen_string_literal: true

require "grape"

require "webhookdb/api"
require "webhookdb/replicator"

class Webhookdb::API::Db < Webhookdb::API::V1
  helpers do
    params :fdw do
      optional :message_fdw, type: Boolean
      optional :message_views, type: Boolean
      optional :message_all, type: Boolean
      requires :remote_server_name, type: String
      requires :fetch_size, type: String
      requires :local_schema, type: String
      requires :view_schema, type: String
    end

    def run_fdw
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
        tables = org.readonly_connection do |db|
          db.tables(schema: org.replication_schema)
        end
        message = ""
        if tables.empty?
          message = "You have not set up any service integrations.\n" \
                    "Use `webhookdb services list` and `webhookdb integrations create` to get started."
        end
        present({tables:, message:})
      end

      desc "Enqueues a database migration."
      params do
        optional :admin_url, type: String, prompt: {
          message: "ADMIN Postgres connection URL, in the form 'postgres://user:password@host:port/dbname',\n" \
                   "that is capable of administrative operations on your database,\n" \
                   "such as creating and dropping schemas and tables.\n" \
                   "Input ADMIN URL, then press Enter:",
          secret: true,
          disable: ->(_) { !Webhookdb::Organization::DbBuilder.allow_public_migrations },
        }

        optional :readonly_url, type: String, prompt: {
          message: "READONLY Postgres connection URL.\n" \
                   "This string is displayed when you ask for your organization's connection information.\n" \
                   "If you are okay with this being your ADMIN URL, leave it blank.\n" \
                   "Input READONLY URL, or leave blank, then press Enter:",
          secret: true,
          optional: true,
          disable: ->(_) { !Webhookdb::Organization::DbBuilder.allow_public_migrations },
        }
      end
      post :migrate_database do
        unless Webhookdb::Organization::DbBuilder.allow_public_migrations
          merror!(403,
                  "Public database migrations are not enabled. Email support@webhookdb.com for more information.",
                  code: "migrations_disabled",
                  alert: true,)
        end
        ensure_admin!
        org = lookup_org!
        # if the readonly url is blank, default to the admin url
        readonly_url = params[:readonly_url].blank? ? params[:admin_url] : params[:readonly_url]
        dbm = Webhookdb::Organization::DatabaseMigration.enqueue(
          admin_connection_url_raw: params[:admin_url],
          readonly_connection_url_raw: readonly_url,
          public_host: "",
          started_by: current_customer,
          organization: org,
        )
        message = "Your database migration has been enqueued. You'll recieve an email when it is complete."
        status 200
        present dbm, with: Webhookdb::API::DatabaseMigrationEntity, message:
      end

      desc "Gets list of database migrations for org."
      get :migrations do
        org = lookup_org!
        dbms = org.database_migrations
        message = ""
        message = "Organization #{org.name} has no database migrations" if dbms.empty?
        status 200
        present_collection dbms, with: Webhookdb::API::DatabaseMigrationEntity, message:
      end

      desc "Execute an arbitrary query against an org's connection string" do
        headers Webhookdb::API::ConnstrAuth.headers_desc
      end
      params do
        optional :query, type: String, prompt: "Input your SQL query, and then press Enter:"
      end
      post :sql do
        org = lookup_org!(allow_connstr_auth: true)
        begin
          r = org.execute_readonly_query(params[:query])
        rescue Sequel::DatabaseError => e
          self.logger.error("db_query_database_error", error: e)
          # We want to handle InsufficientPrivileges and UndefinedTable explicitly
          # since we can hint the user at what to do.
          # Otherwise, we should just return the Postgres exception.
          case e.wrapped_exception
            when PG::UndefinedTable
              missing_table = e.wrapped_exception.message.match(/relation (.+) does not/)&.captures&.first
              msg = "The table #{missing_table} does not exist. Run `webhookdb db tables` to see available tables." if
                missing_table
            when PG::InsufficientPrivilege
              msg = "You do not have permission to perform this query. Queries must be read-only."
          else
              msg = e.wrapped_exception.message
          end
          merror!(403, msg, code: "invalid_query")
        end
        status 200
        present({rows: r.rows, headers: r.columns, max_rows_reached: r.max_rows_reached})
      end

      params do
        optional :guard_confirm, prompt: {
          message: "WARNING: This will invalidate your existing database credentials. " \
                   "Enter to proceed, or Ctrl+C to quit:",
          confirm: true,
        }
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
        use :fdw
      end
      post :fdw do
        run_fdw
      end
    end
  end

  resource :organizations do
    route_param :org_identifier, type: String do
      # See https://github.com/lithictech/webhookdb-api/issues/286
      desc "DEPRECATED: Use /v1/db/:key/fdw instead"
      post :fdw do
        run_fdw
      end
    end
  end
end
