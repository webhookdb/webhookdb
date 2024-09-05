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
    setting :pool_class, :timed_queue
    # Set to 'disable' to work around segfault.
    # See https://github.com/ged/ruby-pg/issues/538
    setting :gssencmode, ""
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

  # Faster version of dataset.exclude(column => values)
  # when +column+ has an index.
  # Instead of "where column not in values", which cannot use the index on +column+
  # (it has to walk each row to check if the value is in +values+),
  # it uses, "where +column+ not in the set of rows that have a column in +values+".
  # Concretely, instead of:
  #
  #   SELECT * FROM mytable
  #   WHERE mycolumn NOT IN ('a', 'b', 'c')
  #
  # use this method to build the query:
  #
  #   SELECT * FROM mytable
  #   WHERE mycolumn NOT IN (SELECT mycolumn FROM mytable WHERE mycolumn IN ('a', 'b', 'c'))
  #
  # The explain plan of the first includes:
  #   Filter: (mycolumn <> ALL ('{a,b,c}'::text[]))
  #
  # The explain plan of the second instead includes something like:
  #   Filter: (NOT (hashed SubPlan 1))
  #     SubPlan 1
  #      ->  Index Only Scan using mycolumn_idx on mytable
  #            Index Cond: (mycolumn = ANY ('{a,b,c}'::text[]))
  #
  # I'm not entirely sure why this makes such a difference,
  # but especially with large lists, it certainly does.
  # For smaller lists it may not make a difference, or may have a small negative impact.
  # Postgres17 may obvious the need for this due to IN changes, if so it can be removed.
  #
  # NOTE: If +column+ is not indexed, this method will require a full table scan.
  # Use with caution!
  module_function def where_not_in_using_index(dataset, column, values, full_dataset: nil)
    return dataset if values.blank?
    full_dataset ||= dataset.db[dataset.opts[:from].first]
    found = full_dataset.where(column => values)
    return dataset.exclude(column => found.select(column))
  end
end
