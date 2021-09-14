# frozen_string_literal: true

require "appydays/configurable"
require "appydays/loggable"

require "webhookdb/organization"

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

    after_configured do
      self.available_server_urls = self.server_urls.dup
      self.available_server_urls.concat(self.server_env_vars.map { |e| ENV[e] })
    end
  end

  # When an org is created, it gets its own database containing the service integration tables
  # exclusively for that org. This ensures orgs can be easily isolated from each other.
  # Each org has three connections:
  # - admin, which can modify tables. Used to create service integration tables.
  #   We generally want to avoid using this connection.
  #   Should never be exposed.
  # - readonly, used for reading only the service integration tables
  #   (and not additional PG info tables).
  #   Can safely be exposed to members of the org.
  def self.prepare_database_connections(org)
    return self.new(org).prepare_database_connections
  end

  attr_reader :admin_url, :readonly_url

  def initialize(org)
    @org = org
  end

  def prepare_database_connections
    # Grab a random server url. This will give us a 'superuser'-like url
    # that can create roles and whatever else.
    superuser_str = self.class.available_server_urls.sample
    superuser_url = URI.parse(superuser_str)
    # Use this superuser connection to create the admin role,
    # which will be responsible for the database.
    # While connected as the superuser, we can go ahead and create both roles.
    admin_user = self.randident("ad")
    admin_pwd = self.randident
    ro_user = self.randident("ro")
    ro_pwd = self.randident
    dbname = self.randident('db')
    Sequel.connect(superuser_str) do |conn|
      conn << <<~SQL
        CREATE ROLE #{admin_user} PASSWORD '#{admin_pwd}' NOSUPERUSER CREATEDB CREATEROLE INHERIT LOGIN;
        CREATE ROLE #{ro_user} PASSWORD '#{ro_pwd}' NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT LOGIN;
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

  # prefix with <id>a to avoid ever conflicting database names
  def randident(prefix="")
    return "a#{prefix}#{@org.id}a#{SecureRandom.hex(8)}"
  end

  def _create_conn_url(username, password, uri, dbname)
    return "postgres://#{username}:#{password}@#{uri.host}:#{uri.port}/#{dbname}"
  end

  def self.remove_related_database(org)
    return self.new(org).remove_related_database
  end

  # To remove related databases and users, we must
  # 1) find the server hosting the database, which will itself contain the admin creds
  #    suitable for having created it in the first place.
  # 2) delete the database, using info extracted from the admin connection (run from the server conn)
  # 3) delete each user (run from the server conn)
  # We need these workarounds because we cannot drop the admin database while we're connected to it
  # (and we probably don't want the admin role trying to delete itself).
  def remove_related_database
    return if @org.admin_connection_url.blank?
    Webhookdb::ConnectionCache.disconnect(@org.admin_connection_url)
    Webhookdb::ConnectionCache.disconnect(@org.readonly_connection_url)
    admin_url = URI.parse(@org.admin_connection_url)
    superuser_str = self.class.available_server_urls.find do |sstr|
      surl = URI.parse(sstr)
      surl.host == admin_url.host && surl.port == admin_url.port
    end
    if superuser_str.blank?
      msg = "Could not find a matching server url for #{admin_url} in #{self.class.available_server_urls}"
      raise msg
    end
    Sequel.connect(superuser_str) do |conn|
      conn << "DROP DATABASE #{@org.dbname}"
      conn << "DROP USER #{@org.readonly_user}"
      conn << "DROP USER #{@org.admin_user}"
    end
  end
end
