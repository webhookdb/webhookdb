# frozen_string_literal: true

require "open3"

class Webhookdb::Snowflake
  include Appydays::Configurable
  include Appydays::Loggable

  configurable(:snowflake) do
    setting :run_tests, false
    setting :test_url, "snowflake://user:pwd@host/dbname"
    setting :snowsql, "snowsql"
  end

  # Given a Snowflake URL, return the command line args.
  # Args for the commandline can be traditional URL pieces (host -> account, user/password, etc),
  # or passed as query params.
  # Rules are:
  # - Any query param exactly matching accountname/username/dbname/schemaname/rolename/warehouse
  #   is used.
  # - Any query param matching account/user/db/schema/role is used.
  # - URI hostname is used as accountname, basic auth user as username, and uri path as dbname.
  # - Password is pulled from query param 'password' or uri basic auth password.
  def self.parse_url_to_cli_args(url, format: "json")
    uri = URI(url)
    params = Rack::Utils.parse_query(uri.query)
    password = params["password"] || uri.password
    raise ArgumentError, "must provide password in uri basic auth or query params" if password.blank?
    cli = [
      self.snowsql,
      "-o", "friendly=false",
      "-o", "output_format=#{format}",
      "-o", "timing=false",
      "--accountname", params["accountname"] || params["account"] || uri.hostname || "",
      "--username", params["username"] || params["user"] || uri.user || "",
      "--dbname", params["dbname"] || params["db"] || uri.path&.delete_prefix("/") || "",
    ]
    raise ArgumentError, "url requires account (host), user, and db (or uri path): #{url}" if cli.include?("")

    if (schemaname = params["schemaname"] || params["schema"]).present?
      cli.concat(["--schemaname", schemaname])
    end
    if (rolename = params["rolename"] || params["role"]).present?
      cli.concat(["--rolename", rolename])
    end
    cli.concat(["--warehouse", params["warehouse"]]) if params["warehouse"].present?
    return cli, {"SNOWSQL_PWD" => password}
  end

  def self.run_cli(url, query, parse: false, format: "json")
    args, env = self.parse_url_to_cli_args(url, format:)
    args.concat(["-q", query])
    stdout, stderr, status = Open3.capture3(env, *args)

    if stderr.blank? && status.success?
      result = if parse.respond_to?(:call)
                 parse.call(stdout)
      elsif parse && format == "json"
        self._parse_json(stdout)
      else
        stdout
      end
      return result
    end

    self.logger.error("snowflake_error", stdout:, stderr:, status:, cli_args: args)
    msg = "status: #{status}, stderr: #{stderr}, stdout: #{stdout}, query: #{query}"
    raise Webhookdb::InvalidPostcondition, "snowflake failed: #{msg}"
  end

  # We can't parse newline delimited json easily, so split it ourselves and parse each document.
  def self._parse_json(stdout)
    docs = stdout.split("]\n[")
    result = docs.each_with_index.map do |j, i|
      if docs.size > 1
        if i.zero?
          j += "]"
        else
          j = "[" + j
        end
      end
      Yajl::Parser.parse(j.strip)
    end
    return result
  rescue StandardError => e
    msg = "error: #{e}, stdout: #{stdout}"
    raise Webhookdb::InvalidPostcondition, "Error parsing snowsql output: #{msg}"
  end
end
