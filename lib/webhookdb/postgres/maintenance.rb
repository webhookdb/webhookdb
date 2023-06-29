# frozen_string_literal: true

module Webhookdb::Postgres::Maintenance
  include Appydays::Configurable

  configurable(:pg_maintenance) do
    setting :debug, true
    setting :docker, true
    # Match what's available on the server.
    setting :pg_repack_image, "hartmutcouk/pg-repack-docker:1.4.7"
  end

  class Base
    # @!attribute service_integration
    #   @return [Webhookdb::ServiceIntegration]
    attr_reader :service_integration

    def debug? = Webhookdb::Postgres::Maintenance.debug

    def initialize(service_integration)
      @service_integration = service_integration
    end

    def conn_params
      org_uri = URI(self.service_integration.organization.admin_connection_url_raw)
      superuser_url = Webhookdb::Organization::DbBuilder.available_server_urls.find { |u| URI(u).host == org_uri.host }
      raise Webhookdb::InvalidPrecondition, "cannot find superuser url for #{org_uri.host}" if superuser_url.nil?
      sup_uri = URI(superuser_url)
      return {
        user: sup_uri.user,
        password: sup_uri.password,
        host: sup_uri.host,
        port: sup_uri.port,
        database: org_uri.path&.delete_prefix("/"),
        table: self.service_integration.table_name,
      }
    end
  end

  class Query < Base
    def connstr
      h = self.conn_params
      return "postgres://#{h[:user]}:#{h[:password]}@#{h[:host]}:#{h[:port]}/#{h[:database]}"
    end

    def query = raise NotImplementedError

    def fetch
      Sequel.connect(self.connstr) do |c|
        c.fetch(self.query).all
      end
    end

    def run = raise NotImplementedError
    def run_fmt = raise NotImplementedError
  end

  class Command < Base
    def docker? = Webhookdb::Postgres::Maintenance.docker

    def psql_conn_params
      h = self.conn_params
      return [
        "--no-password",
        "-U", h[:user],
        "-h", h[:host],
        "-p", h[:port],
        "--dbname", h[:database],
      ]
    end

    def command_list = raise NotImplementedError
    def docker_image = raise NotImplementedError
    def extension = nil

    def docker_preamble
      return [
        "docker",
        "run",
        "-e",
        "PGPASSWORD=#{self.conn_params[:password]}",
        "-it",
        "--rm",
        self.docker_image,
      ]
    end

    def create_extension_command_list
      a = ["PGPASSWORD=#{self.conn_params[:password]}", "psql"]
      a += self.psql_conn_params
      a << "-c"
      a << "'CREATE EXTENSION IF NOT EXISTS #{self.extension}'"
      return a
    end

    def command_strings
      c = []
      c << self.shelex(self.create_extension_command_list) if self.extension
      c << self.shelex(self.command_list)
      return c
    end

    def shelex(a)
      return a.join(" ")
    end
  end

  class Repack < Command
    def extension = "pg_repack"

    def docker_image = Webhookdb::Postgres::Maintenance.pg_repack_image

    def command_list
      c = []
      c += self.docker_preamble if self.docker?
      c << "pg_repack"
      c += self.psql_conn_params
      c += ["--table", self.conn_params[:table]]
      c << "--no-superuser-check"
      c << "--dry-run"
      c += ["--echo", "--elevel=DEBUG"] if self.debug?
      return c
    end
  end

  class Count < Query
    def query = "SELECT reltuples AS estimate FROM pg_class WHERE relname = '#{self.service_integration.table_name}'"

    def run
      r = self.fetch
      return r[0][:estimate].to_i
    end

    def run_fmt = ActiveSupport::NumberHelper.number_to_delimited(self.run.to_i)
  end

  class Tables < Query
    def query
      return <<~SQL
        SELECT
            relname AS "relation",
            reltuples as "tuples",
            pg_size_pretty(pg_total_relation_size(C .oid)) as "size"
        FROM pg_class C
        LEFT JOIN pg_namespace N ON (N.oid = C.relnamespace)
        WHERE nspname NOT IN ('pg_catalog', 'information_schema')
        AND C.relkind = 'r'
        AND nspname !~ '^pg_toast'
        ORDER BY C.relname
      SQL
    end

    def run
      return self.fetch
    end

    def run_fmt
      rows = self.run
      namejust = rows.map { |r| r[:relation].size }.max
      return rows.map do |r|
        tuples = ActiveSupport::NumberHelper.number_to_delimited(r[:tuples].to_i).rjust(12, " ")
        "#{r[:relation].ljust(namejust + 1, ' ')} #{r[:size].ljust(7, ' ')} #{tuples}"
      end.join("\n")
    end
  end
end
