# frozen_string_literal: true

require "sequel"

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

    # The number of additional connections to add to +max_connections+.
    # Needed to handle cases where there may be considerable background threads with connections.
    setting :additional_pool_size, 0

    # This gets set by default to whatever concurrency is appropriate for the process type.
    # PROC_MODE is set in the initializers in the config dir.
    # It can also be set explicitly.
    # Defaults to 4.
    setting :max_connections, -1
    setting :pool_timeout, 10
    setting :pool_class, :timed_queue
    # Set to 'disable' to work around segfault.
    # See https://github.com/ged/ruby-pg/issues/538
    setting :gssencmode, ""

    after_configured do
      # The PROC_MODE default values match what is in the initializer files that set PROC_MODE.
      self.max_connections = if ENV["DBUTIL_MAX_CONNECTIONS"]
                               ENV.fetch("DBUTIL_MAX_CONNECTIONS", "4").to_i
      elsif ENV["PROC_MODE"] == "sidekiq"
        ENV.fetch("SIDEKIQ_CONCURRENCY", "10").to_i
      elsif ENV["PROC_MODE"] == "puma"
        ENV.fetch("RAILS_MAX_THREADS", "4").to_i
      else
        4
      end
      raise Webhookdb::InvalidPostcondition, "max_connections is misconfigured, cannot be <= 0" if
        self.max_connections <= 0
      self.max_connections += self.additional_pool_size
    end
  end

  # Needed when we need to work with a source.
  MOCK_CONN = Sequel.connect("mock://")

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

  private module_function def conn_opts(opts)
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
    res[:pool_class] ||= Webhookdb::Dbutil.pool_class
    res[:driver_options] = {}
    (res[:driver_options][:gssencmode] = Webhookdb::Dbutil.gssencmode) if Webhookdb::Dbutil.gssencmode.present?
    return res
  end

  module_function def displaysafe_url(url)
    u = URI(url)
    u.user = "***"
    u.password = "***"
    return u.to_s
  end

  module_function def reduce_expr(dataset, op_symbol, operands, method: :where)
    return dataset if operands.blank?
    present_ops = operands.select(&:present?)
    return dataset if present_ops.empty?
    full_op = present_ops.reduce(&op_symbol)
    return dataset.send(method, full_op)
  end
end
