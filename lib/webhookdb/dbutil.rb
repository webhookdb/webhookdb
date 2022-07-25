# frozen_string_literal: true

# Mixin that provides helpers when dealing with databases and connections.
#
# Use borrow_conn to create a connection that is disconnected after the block runs.
# A block must be given.
# By default, this connection uses the Webhookdb logger,
# and uses test: false and keep_reference: false Sequel.connect options,
# since this is a quick-lived and self-managed connection.
#
# Use take_conn where you will take care of disconnecting the connection.
# Note you MUST take care to call `disconnect` at some point
# or connections will leak.
module Webhookdb::Dbutil
  include Appydays::Configurable

  # See http://sequel.jeremyevans.net/rdoc/files/doc/opening_databases_rdoc.html#label-General+connection+options
  # for Sequel option details.
  configurable(:dbutil) do
    # The number of (Float) seconds that should be considered "slow" for a
    # single query; queries that take longer than this amount of time will be logged
    # at `warn` level.
    setting :slow_query_seconds, 0.1

    # Default this to whatever concurrency is appropriate for the process type.
    # PROC_MODE is set in the initializers in the config dir.
    setting :max_connections,
            (if ENV["PROC_MODE"] == "sidekiq"
               ENV.fetch("SIDEKIQ_CONCURRENCY", "10").to_i
            elsif ENV["PROC_MIDE"] == "puma"
              ENV.fetch("WEB_CONCURRENCY", "4").to_i
            else
              4
            end)
    setting :pool_timeout, 10
  end

  module_function def borrow_conn(url, **opts, &block)
    raise LocalJumpError, "borrow_conn requires a block" if block.nil?
    opts = conn_opts(opts)
    Sequel.connect(url, **opts, &block)
  end

  module_function def take_conn(url, **opts, &block)
    raise LocalJumpError, "take_conn cannot use a block" unless block.nil?
    opts = conn_opts(opts)
    return Sequel.connect(url, **opts, &block)
  end

  private def conn_opts(opts)
    res = Webhookdb::Dbutil.configured_connection_options
    res.merge!(opts)
    res[:test] = false unless res.key?(:test)
    res[:loggers] = [Webhookdb.logger] unless res.key?(:logger) || res.key?(:loggers)
    res[:keep_reference] = false unless res.key?(:keep_reference)
    return res
  end

  def self.configured_connection_options
    res = {}
    res[:sql_log_level] ||= :debug
    res[:log_warn_duration] ||= Webhookdb::Dbutil.slow_query_seconds
    res[:max_connections] ||= Webhookdb::Dbutil.max_connections
    res[:pool_timeout] ||= Webhookdb::Dbutil.pool_timeout
    return res
  end

  module_function def displaysafe_url(url)
    u = URI(url)
    u.user = "***"
    u.password = "***"
    return u.to_s
  end
end
