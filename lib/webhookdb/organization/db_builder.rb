# frozen_string_literal: true

require "appydays/configurable"
require "appydays/loggable"

require "webhookdb/organization"
require "webhookdb/cloudflare"

# When an org is created, it gets its own database containing the service integration tables
# exclusively for that org. This ensures orgs can be easily isolated from each other.
#
# Each org has two connections:
# - admin, which can modify tables. Used to create service integration tables.
#   We generally want to avoid using this connection.
#   Should never be exposed.
# - readonly, used for reading only the service integration tables
#   (and not additional PG info tables).
#   Can safely be exposed to members of the org.
class Webhookdb::Organization::DbBuilder
  include Appydays::Configurable
  include Appydays::Loggable
  extend Webhookdb::MethodUtilities

  singleton_attr_accessor :available_server_urls

  configurable(:db_builder) do
    # Server urls are absolute urls that define servers which can be chosen for organization DBs.
    # Space-separate multiple servers.
    setting :server_urls, [], convert: ->(s) { s.split.map(&:strip) }
    # Server env vars are the names of environment variables whose value are
    # each a server which can be chosen for organization DBs.
    # Allows you to use dynamically configured servers.
    # Space-separate multiple env vars.
    setting :server_env_vars, ["DATABASE_URL"], convert: ->(s) { s.split.map(&:strip) }
    # Create a CNAME record when building the database connection.
    setting :create_cname_for_connection_urls, false
    # The Cloudflare zone ID that DNS records will be created in.
    # NOTE: It is required that the Cloudflare API token has access to this zone.
    setting :cloudflare_dns_zone_id, "testdnszoneid"

    after_configured do
      self.available_server_urls = self.server_urls.dup
      self.available_server_urls.concat(self.server_env_vars.map { |e| ENV[e] })
    end
  end

  READONLY_CONN_LIMIT = 50

  attr_reader :admin_url, :readonly_url

  def initialize(org)
    @org = org
  end

  def prepare_database_connections
    # Grab a random server url. This will give us a 'superuser'-like url
    # that can create roles and whatever else.
    superuser_str = self._choose_superuser_url
    superuser_url = URI.parse(superuser_str)
    # Use this superuser connection to create the admin role,
    # which will be responsible for the database.
    # While connected as the superuser, we can go ahead and create both roles.
    admin_user = self.randident("ad")
    admin_pwd = self.randident
    ro_user = self.randident("ro")
    ro_pwd = self.randident
    dbname = self.randident("db")
    Sequel.connect(superuser_str) do |conn|
      conn << <<~SQL
        CREATE ROLE #{admin_user} PASSWORD '#{admin_pwd}' NOSUPERUSER CREATEDB CREATEROLE INHERIT LOGIN;
        CREATE ROLE #{ro_user} PASSWORD '#{ro_pwd}' NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT LOGIN;
        ALTER USER #{ro_user} WITH CONNECTION LIMIT #{READONLY_CONN_LIMIT};
        GRANT #{admin_user} TO CURRENT_USER;
      SQL
      # Cannot be in the same statement as above since that's one transaction.
      conn << "CREATE DATABASE #{dbname} OWNER #{admin_user};"
      conn << "REVOKE ALL PRIVILEGES ON DATABASE #{dbname} FROM public;"
    end

    # Now that we've created the admin role and have a database,
    # we must disconnect and connect to the new database.
    # This MUST be done as superuser; for some reason,
    # the public schema (which we need to revoke on) belongs to the superuser,
    # NOT the DB owner: https://pgsql-general.postgresql.narkive.com/X9VKOPIW
    superuser_in_db_str = self._create_conn_url(superuser_url.user, superuser_url.password, superuser_url, dbname)
    Sequel.connect(superuser_in_db_str) do |conn|
      conn << <<~SQL
        -- Revoke all rights from readonly user, and public role, which all users have.
        REVOKE ALL ON DATABASE #{dbname} FROM PUBLIC, #{ro_user};
        REVOKE ALL ON SCHEMA public FROM PUBLIC, #{ro_user};
        REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC, #{ro_user};
        -- Allow the readonly user to select stuff
        GRANT CONNECT ON DATABASE #{dbname} TO #{ro_user};
        GRANT USAGE ON SCHEMA public TO #{ro_user};
        GRANT SELECT ON ALL TABLES IN SCHEMA public TO #{ro_user};
        -- Now that we have modified public schema as superuser,
        -- we can grant ownership to the admin user, so they can do modification in the future.
        ALTER SCHEMA public OWNER TO #{admin_user};
      SQL
    end
    @admin_url = self._create_conn_url(admin_user, admin_pwd, superuser_url, dbname)
    # We MUST modify the default privs AFTER changing ownership.
    # Changing ownership seems to reset default piv grants (and it cannot be done after transferring ownership)
    Sequel.connect(@admin_url) do |conn|
      conn << "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO #{ro_user};"
    end
    @readonly_url = self._create_conn_url(ro_user, ro_pwd, superuser_url, dbname)
    return self
  end

  # Return the superuser url for the org to use when creating its DB connections.
  # Right now this is just choosing a random server url,
  # but could be more complex, like choosing the server with the lowest utilization.
  protected def _choose_superuser_url
    superuser_str = self.class.available_server_urls.sample
    return superuser_str
  end

  # prefix with <id>a to avoid ever conflicting database names
  def randident(prefix="")
    return "a#{prefix}#{@org.id}a#{SecureRandom.hex(8)}"
  end

  def _create_conn_url(username, password, uri, dbname)
    return "postgres://#{username}:#{password}@#{uri.host}:#{uri.port}/#{dbname}"
  end

  # Create the CNAME record specific to this org,
  # so that the DB it is hosted on is reachable via a nice URL,
  # rather than connecting directly to the host.
  #
  # If create_cnames is false,
  # this method no-ops, so we don't spam cloudflare during integration tests,
  # or need to httpmock everything during unit tests.
  #
  # Otherwise, create the CNAME like "myorg.db node.rds.amazonaws.com",
  # and set org.public_host to "myorg.db.webhookdb.dev". The "webhookdb.dev" value
  # comes from the Cloudflare DNS response, and corresponds to the zone
  # that `cloudflare_dns_zone_id` identifies.
  def create_public_host_cname(conn_url)
    return nil unless self.class.create_cname_for_connection_urls
    db_host = URI.parse(conn_url).host
    cname = Webhookdb::Cloudflare.create_zone_dns_record(
      type: "CNAME",
      zone_id: self.class.cloudflare_dns_zone_id,
      name: "#{@org.key}.db",
      content: db_host,
    )
    @org.public_host = cname["result"]["name"]
    @org.cloudflare_dns_record_json = cname
    return self
  end

  # To remove related databases and users, we must
  # 1) find the server hosting the database, which will itself contain the admin creds
  #    suitable for having created it in the first place.
  # 2) delete the database, using info extracted from the admin connection (run from the server conn)
  # 3) delete each user (run from the server conn)
  # We need these workarounds because we cannot drop the admin database while we're connected to it
  # (and we probably don't want the admin role trying to delete itself).
  def remove_related_database
    return if @org.admin_connection_url_raw.blank?
    Webhookdb::ConnectionCache.disconnect(@org.admin_connection_url_raw)
    Webhookdb::ConnectionCache.disconnect(@org.readonly_connection_url_raw)
    superuser_str = self._find_superuser_url_str
    Sequel.connect(superuser_str) do |conn|
      conn << "DROP DATABASE #{@org.dbname}"
      conn << "DROP USER #{@org.readonly_user}"
      conn << "DROP USER #{@org.admin_user}"
    end
  end

  protected def _find_superuser_url_str
    admin_url = URI.parse(@org.admin_connection_url_raw)
    superuser_str = self.class.available_server_urls.find do |sstr|
      surl = URI.parse(sstr)
      surl.host == admin_url.host && surl.port == admin_url.port
    end
    if superuser_str.blank?
      msg = "Could not find a matching server url for #{admin_url} in #{self.class.available_server_urls}"
      raise msg
    end
    return superuser_str
  end

  def roll_connection_credentials
    superuser_uri = URI(self._find_superuser_url_str)
    orig_readonly_user = URI(@org.readonly_connection_url_raw).user
    orig_admin_user = URI(@org.admin_connection_url_raw).user
    admin_user = self.randident("ad")
    admin_pwd = self.randident
    ro_user = self.randident("ro")
    ro_pwd = self.randident
    Webhookdb::ConnectionCache.disconnect(@org.admin_connection_url_raw)
    Webhookdb::ConnectionCache.disconnect(@org.readonly_connection_url_raw)
    Sequel.connect(superuser_uri.to_s) do |conn|
      conn << <<~SQL
        ALTER ROLE #{orig_readonly_user} RENAME TO #{ro_user};
        ALTER ROLE #{ro_user} WITH PASSWORD '#{ro_pwd}';
        ALTER ROLE #{orig_admin_user} RENAME TO #{admin_user};
        ALTER ROLE #{admin_user} WITH PASSWORD '#{admin_pwd}';
      SQL
    end
    @admin_url = self._create_conn_url(admin_user, admin_pwd, superuser_uri, @org.dbname)
    @readonly_url = self._create_conn_url(ro_user, ro_pwd, superuser_uri, @org.dbname)
  end

  def generate_fdw_payload(
    remote_server_name:,
    fetch_size:,
    local_schema:,
    view_schema:
  )
    raise ArgumentError, "no arg can be blank" if
      [remote_server_name, fetch_size, local_schema, view_schema].any?(&:blank?)
    conn = URI(@org.readonly_connection_url)
    fdw_sql = <<~FDW_SERVER
      CREATE EXTENSION IF NOT EXISTS postgres_fdw;
      DROP SERVER IF EXISTS #{remote_server_name} CASCADE;
      CREATE SERVER #{remote_server_name}
        FOREIGN DATA WRAPPER postgres_fdw
        OPTIONS (host '#{conn.host}', port '#{conn.port}', dbname '#{conn.path[1..]}', fetch_size '#{fetch_size}');

      CREATE USER MAPPING FOR CURRENT_USER
        SERVER #{remote_server_name}
        OPTIONS (user '#{conn.user}', password '#{conn.password}');

      CREATE SCHEMA IF NOT EXISTS #{local_schema};
      IMPORT FOREIGN SCHEMA public
        FROM SERVER #{remote_server_name}
        INTO #{local_schema};

      CREATE SCHEMA IF NOT EXISTS #{view_schema};
    FDW_SERVER

    views_for_integrations = @org.service_integrations.to_h do |sint|
      cmd = "CREATE MATERIALIZED VIEW IF NOT EXISTS #{view_schema}.#{sint.service_name} " \
            "AS SELECT * FROM #{local_schema}.#{sint.table_name};"
      [sint.opaque_id, cmd]
    end
    views_sql = views_for_integrations.values.sort.join("\n")

    result = {
      fdw_sql:,
      views_sql:,
      compound_sql: "#{fdw_sql}\n\n#{views_sql}",
      views: views_for_integrations,
    }
    return result
  end
end
