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
  include Webhookdb::Dbutil
  extend Webhookdb::MethodUtilities

  class IsolatedOperationError < StandardError; end

  DATABASE = "database"
  SCHEMA = "schema"
  USER = "user"
  NONE = "none"

  VALID_ISOLATION_MODES = [
    "#{DATABASE}+#{USER}",
    "#{DATABASE}+#{SCHEMA}+#{USER}",
    SCHEMA,
    "#{SCHEMA}+#{USER}",
    NONE,
  ].freeze

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
    # Determines whether we allow orgs to handle their own migrations.
    # Used for self-hosted databases.
    setting :allow_public_migrations, false
    # Create a CNAME record when building the database connection.
    setting :create_cname_for_connection_urls, false
    # The Cloudflare zone ID that DNS records will be created in.
    # NOTE: It is required that the Cloudflare API token has access to this zone.
    setting :cloudflare_dns_zone_id, "testdnszoneid"
    # See README for more details.
    setting :isolation_mode, "database+user"

    after_configured do
      unless VALID_ISOLATION_MODES.include?(self.isolation_mode)
        msg = "Invalid DB_BUILDER_ISOLATION_MODE '#{self.isolation_mode}', " \
              "valid modes are: #{VALID_ISOLATION_MODES.join(', ')}"
        raise KeyError, msg
      end
      self.available_server_urls = self.server_urls.dup
      self.available_server_urls.concat(self.server_env_vars.map { |e| ENV.fetch(e, nil) })
    end
  end

  READONLY_CONN_LIMIT = 50

  def self.isolate?(type)
    return self.isolation_mode.include?(type)
  end

  attr_reader :admin_url, :readonly_url

  def initialize(org)
    @org = org
  end

  def default_replication_schema
    raise Webhookdb::InvalidPrecondition, "Org must have a key to calculate the replication schema" if @org.key.blank?
    return "public" unless self.class.isolate?(SCHEMA)
    return "whdb_#{@org.key}"
  end

  def prepare_database_connections
    # Grab a random server url. This will give us a 'superuser'-like url
    # that can create roles and whatever else.
    superuser_str = self._choose_superuser_url
    case self.class.isolation_mode
      when "database+user"
        self._prepare_database_connections_database_user(superuser_str)
      when "database+schema+user"
        self._prepare_database_connections_database_schema_user(superuser_str)
      when "schema"
        self._prepare_database_connections_schema(superuser_str)
      when "schema+user"
        self._prepare_database_connections_schema_user(superuser_str)
      when "none"
        self._prepare_database_connections_none(superuser_str)
      else
        raise "Did not expect mode #{self.class.isolation_mode}"
    end
    return self
  end

  def _prepare_database_connections_database_user(superuser_url_str)
    superuser_url = URI.parse(superuser_url_str)
    # Use this superuser connection to create the admin role,
    # which will be responsible for the database.
    # While connected as the superuser, we can go ahead and create both roles.
    admin_user = self.randident("ad")
    admin_pwd = self.randident
    ro_user = self.randident("ro")
    ro_pwd = self.randident
    dbname = self.randident("db")
    # Do not log this
    borrow_conn(superuser_url_str, loggers: []) do |conn|
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
    schema = self._org_schema
    borrow_conn(superuser_in_db_str) do |conn|
      conn << <<~SQL
        -- Revoke all rights from readonly user, and public role, which all users have.
        REVOKE ALL ON DATABASE #{dbname} FROM PUBLIC, #{ro_user};
        REVOKE ALL ON SCHEMA public FROM PUBLIC, #{ro_user};
        REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC, #{ro_user};
        -- Create the schema if needed. In most cases this is 'public' so it isn't.
        CREATE SCHEMA IF NOT EXISTS #{schema};
        -- Allow the readonly user to select stuff
        GRANT CONNECT ON DATABASE #{dbname} TO #{ro_user};
        GRANT USAGE ON SCHEMA #{schema} TO #{ro_user};
        GRANT SELECT ON ALL TABLES IN SCHEMA #{schema} TO #{ro_user};
        -- Now that we have modified public/replication schema as superuser,
        -- we can grant ownership to the admin user, so they can do modification in the future.
        ALTER SCHEMA public OWNER TO #{admin_user};
        ALTER SCHEMA #{schema} OWNER TO #{admin_user};
      SQL
    end
    @admin_url = self._create_conn_url(admin_user, admin_pwd, superuser_url, dbname)
    # We MUST modify the default privs AFTER changing ownership.
    # Changing ownership seems to reset default piv grants (and it cannot be done after transferring ownership)
    borrow_conn(@admin_url) do |conn|
      conn << "ALTER DEFAULT PRIVILEGES IN SCHEMA #{schema} GRANT SELECT ON TABLES TO #{ro_user};"
    end
    @readonly_url = self._create_conn_url(ro_user, ro_pwd, superuser_url, dbname)
  end

  def _prepare_database_connections_database_schema_user(superuser_url_str)
    self._prepare_database_connections_database_user(superuser_url_str)
    # Revoke everything on public schema, so our readonly user cannot access it.
    borrow_conn(@admin_url) do |conn|
      conn << "REVOKE ALL ON SCHEMA public FROM public"
    end
  end

  def _prepare_database_connections_schema(superuser_url_str)
    borrow_conn(superuser_url_str) do |conn|
      conn << "CREATE SCHEMA IF NOT EXISTS #{self._org_schema};"
    end
    @admin_url = superuser_url_str
    @readonly_url = superuser_url_str
  end

  def _prepare_database_connections_schema_user(superuser_url_str)
    ro_user = self.randident("ro")
    ro_pwd = self.randident
    schema = self._org_schema
    borrow_conn(superuser_url_str) do |conn|
      conn << <<~SQL
        -- Create readonly role and make sure it cannot access public stuff
        CREATE ROLE #{ro_user} PASSWORD '#{ro_pwd}' NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT LOGIN;
        ALTER USER #{ro_user} WITH CONNECTION LIMIT #{READONLY_CONN_LIMIT};
        REVOKE ALL ON SCHEMA public FROM #{ro_user};
        REVOKE CREATE ON SCHEMA public FROM #{ro_user};
        REVOKE ALL ON ALL TABLES IN SCHEMA public FROM #{ro_user};
        -- Create the schema and ensure readonly user can access it
        -- Also remove public role access so other readonly users cannot access it.
        CREATE SCHEMA IF NOT EXISTS #{schema};
        REVOKE ALL ON SCHEMA #{schema} FROM PUBLIC, #{ro_user};
        REVOKE ALL ON ALL TABLES IN SCHEMA #{schema} FROM PUBLIC, #{ro_user};
        GRANT USAGE ON SCHEMA #{schema} TO #{ro_user};
        GRANT SELECT ON ALL TABLES IN SCHEMA #{schema} TO #{ro_user};
        ALTER DEFAULT PRIVILEGES IN SCHEMA #{schema} GRANT SELECT ON TABLES TO #{ro_user};
      SQL
    end
    @admin_url = superuser_url_str
    @readonly_url = self._replace_url_auth(superuser_url_str, ro_user, ro_pwd)
  end

  def _prepare_database_connections_none(superuser_url_str)
    @admin_url = superuser_url_str
    @readonly_url = superuser_url_str
  end

  # Return the superuser url for the org to use when creating its DB connections.
  # Right now this is just choosing a random server url,
  # but could be more complex, like choosing the server with the lowest utilization.
  protected def _choose_superuser_url
    superuser_str = self.class.available_server_urls.sample
    return superuser_str
  end

  protected def _org_schema
    return Webhookdb::DBAdapter::PG.new.escape_identifier(@org.replication_schema)
  end

  # prefix with <id>a to avoid ever conflicting database names
  def randident(prefix="")
    return "a#{prefix}#{@org.id}a#{SecureRandom.hex(8)}"
  end

  def _create_conn_url(username, password, uri, dbname)
    return "postgres://#{username}:#{password}@#{uri.host}:#{uri.port}/#{dbname}"
  end

  def _replace_url_auth(url, user, pass)
    uri = URI(url)
    uri.user = user
    uri.password = pass
    return uri.to_s
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
    superuser_str = self._find_superuser_url_str
    # Cannot use conn cache since we may be removing ourselves
    borrow_conn(superuser_str) do |conn|
      case self.class.isolation_mode
        when "database+user", "database+schema+user"
          Webhookdb::ConnectionCache.disconnect(@org.admin_connection_url_raw)
          Webhookdb::ConnectionCache.disconnect(@org.readonly_connection_url_raw)
          conn << "DROP DATABASE #{@org.dbname};"
          conn << "DROP USER #{@org.readonly_user};" unless @org.single_db_user?
          conn << "DROP USER #{@org.admin_user};"
        when "schema+user"
          Webhookdb::ConnectionCache.disconnect(@org.readonly_connection_url_raw)
          conn << <<~SQL
            DROP SCHEMA IF EXISTS #{self._org_schema} CASCADE;
            DROP OWNED BY #{@org.readonly_user};
            DROP USER #{@org.readonly_user};
          SQL
        when "schema"
          conn << "DROP SCHEMA IF EXISTS #{self._org_schema} CASCADE"
        when "none"
          nil
        else
          raise "not supported yet"
      end
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
    raise IsolatedOperationError, "cannot roll credentials without a user isolation mode" unless
      self.class.isolate?(USER)
    superuser_uri = URI(self._find_superuser_url_str)
    orig_readonly_user = URI(@org.readonly_connection_url_raw).user
    ro_user = self.randident("ro")
    ro_pwd = self.randident
    @readonly_url = self._create_conn_url(ro_user, ro_pwd, superuser_uri, @org.dbname)
    lines = [
      "ALTER ROLE #{orig_readonly_user} RENAME TO #{ro_user};",
      "ALTER ROLE #{ro_user} WITH PASSWORD '#{ro_pwd}';",
    ]
    if self.class.isolate?(DATABASE)
      # Roll admin credentials for a separate database.
      # For schema isolation, we assume admin is the superuser so cannot roll creds.
      orig_admin_user = URI(@org.admin_connection_url_raw).user
      admin_user = self.randident("ad")
      admin_pwd = self.randident
      lines.push(
        "ALTER ROLE #{orig_admin_user} RENAME TO #{admin_user};",
        "ALTER ROLE #{admin_user} WITH PASSWORD '#{admin_pwd}';",
      )
      @admin_url = self._create_conn_url(admin_user, admin_pwd, superuser_uri, @org.dbname)
    else
      @admin_url = @org.admin_connection_url_raw
    end
    # New conn so we don't log it
    borrow_conn(superuser_uri.to_s, loggers: []) do |conn|
      conn << lines.join("\n")
    end
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
      IMPORT FOREIGN SCHEMA #{self._org_schema}
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

  def migration_replication_schema_sql(old_schema, new_schema)
    can_migrate_to_public = self.class.isolate?(DATABASE)
    if new_schema == "public" && !can_migrate_to_public
      raise IsolatedOperationError,
            "cannot migrate to public schema when using '#{self.class.isolation_mode}' isolation"
    end
    ad = Webhookdb::DBAdapter::PG.new
    qold_schema = ad.escape_identifier(old_schema)
    qnew_schema = ad.escape_identifier(new_schema)
    lines = []
    # lines << "ALTER SCHEMA #{qold_schema} RENAME TO #{qnew_schema};"
    # lines << "CREATE SCHEMA IF NOT EXISTS public;"
    lines << "CREATE SCHEMA IF NOT EXISTS #{qnew_schema};"
    @org.service_integrations.each do |sint|
      lines << ("ALTER TABLE IF EXISTS %s.%s SET SCHEMA %s;" %
        [qold_schema, ad.escape_identifier(sint.table_name), qnew_schema])
    end
    if self.class.isolate?(USER)
      ro_user = @org.readonly_user
      lines << "GRANT USAGE ON SCHEMA #{qnew_schema} TO #{ro_user};"
      lines << "GRANT SELECT ON ALL TABLES IN SCHEMA #{qnew_schema} TO #{ro_user};"
      lines << "REVOKE ALL ON SCHEMA #{qold_schema} FROM #{ro_user};" unless @org.single_db_user?
      lines << "REVOKE ALL ON ALL TABLES IN SCHEMA #{qold_schema} FROM #{ro_user};" unless @org.single_db_user?
      lines << "ALTER DEFAULT PRIVILEGES IN SCHEMA #{qnew_schema} GRANT SELECT ON TABLES TO #{ro_user};"
    end
    # lines << "DROP SCHEMA #{qold_schema} CASCADE;"
    return lines.join("\n")
  end
end
