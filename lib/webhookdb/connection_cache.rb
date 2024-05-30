# frozen_string_literal: true

require "appydays/configurable"
require "appydays/loggable"

require "webhookdb"

# Keep a dynamic cache of open database connections.
# Very similar in behavior to Sequel::DATABASES,
# but we need to prune connections that have not been inactive for a while.
#
# When `borrow` is called, either a new connection is made,
# or an existing one used, for that URL. The connection is yield to the block.
#
# Then, after the block is called,
# if 'prune_interval' has elapsed since the last prune,
# prune all connections with 0 current connections,
# _other than the connection just used_.
# Because this connection was just used,
# we assume it will be used again soon.
#
# The idea here is that:
# - We cannot connect to the DB statically; each org can have its own DB,
#   so storing it statically would increase DB connections to the the number of orgs in the database.
# - So we replace the organization/synchronization done in Sequel::DATABASES with ConnectionCache.
# - Any number of worker threads need access to the same DB; rather than connecting inline,
#   which is very slow, all DB connections for an org (or across orgs if not in database isolation)
#   can share connections via ConnectionCache.
# - In single-org/db environments, the active organization will always always be the same,
#   so the connection is never returned.
# - In multi-org/db environments, busy orgs will likely stay busy. But a reconnect isn't the end
#   of the world.
# - It seems more efficient to be pessimistic about future use, and prune anything with 0 connections,
#   rather than optimistic, and use an LRU or something similar, since the connections are somewhat
#   expensive resources to keep open for now reason. That said, we could switch this out for an LRU
#   it the pessimistic pruning results in many reconnections. It would also be reasonable to increase
#   the prune interval to avoid disconnecting as frequently.
#
# Note that, due to certain implementation details, such as setting timeouts and automatic transaction handling,
# we implement our own threaded connection pooling, so use the SingleThreadedConnectionPool in Sequel
# and manage multiple threads on our own.
class Webhookdb::ConnectionCache
  include Appydays::Configurable
  include Appydays::Loggable
  extend Webhookdb::MethodUtilities
  include Webhookdb::Dbutil

  class ReentranceError < StandardError; end

  configurable(:connection_cache) do
    # If this many seconds has elapsed since the last connecton was borrowed,
    # prune connections with no pending borrows.
    setting :prune_interval, 120

    # If a connection hasn't been used in this long, validate it before reusing it.
    setting :idle_timeout, 20.minutes

    # Seconds for the :fast timeout option.
    setting :timeout_fast, 30
    # Seconds for the :slow timeout option.
    setting :timeout_slow, 180
    # Seconds for the :slow_schema timeout option.
    setting :timeout_slow_schema, 30.minutes.to_i
  end

  singleton_attr_accessor :_instance

  def self.borrow(url, **kw, &)
    return self._instance.borrow(url, **kw, &)
  end

  def self.disconnect(url)
    self._instance.disconnect(url)
  end

  def self.force_disconnect_all
    self._instance.force_disconnect_all
  end

  attr_accessor :dbs_for_urls, :prune_interval, :last_pruned_at

  def initialize(prune_interval:)
    @mutex = Mutex.new
    @dbs_for_urls = {}
    @prune_interval = prune_interval
    @last_pruned_at = Time.now
  end

  Available = Struct.new(:connection, :at) do
    delegate :disconnect, to: :connection

    # Return +connection+ if it has not been idle long enough,
    # or if it has been idle, then validate it (SELECT 1), and return +connection+
    # if it's valid, or +nil+ if the database disconnected it.
    def validated_connection
      needs_validation_at = self.at + Webhookdb::ConnectionCache.idle_timeout
      return self.connection if needs_validation_at > Time.now
      begin
        self.connection << "SELECT 1"
        return self.connection
      rescue Sequel::DatabaseDisconnectError
        self.connection.disconnect
        return nil
      end
    end
  end

  # Connect to the database at the given URL.
  # borrow is not re-entrant, so if the current thread already owns a connection
  # to the given url, raise a ReentrantError.
  # If the url has a DB not in use by any thread,
  # yield that.
  # If the url has no DBs opened, or all are checked out,
  # create and yield a new connection.
  # See class docs for more details.
  def borrow(url, transaction: false, timeout: nil, &block)
    raise LocalJumpError if block.nil?
    raise ArgumentError, "url cannot be blank" if url.blank?
    now = Time.now
    if timeout.is_a?(Symbol)
      timeout_name = "timeout_#{timeout}"
      begin
        timeout = Webhookdb::ConnectionCache.send(timeout_name)
      rescue NoMethodError
        raise NoMethodError, "no timeout accessor :#{timeout_name}"
      end
    end
    t = Thread.current
    conn = nil
    @mutex.synchronize do
      db_loans = @dbs_for_urls[url] ||= {loaned: {}, available: []}
      if db_loans[:loaned].key?(t)
        raise ReentranceError,
              "ConnectionCache#borrow is not re-entrant for the same database since the connection has stateful config"
      end
      if (available = db_loans[:available].pop)
        # If the connection doesn't validate, it won't be in :available at this point, so don't worry about it.
        conn = available.validated_connection
      end
      conn ||= take_conn(url, single_threaded: true, extensions: [:pg_json, :pg_streaming])
      db_loans[:loaned][t] = conn
    end
    conn << "SET statement_timeout TO #{timeout * 1000}" if timeout.present?
    conn << "BEGIN;" if transaction
    begin
      result = yield conn
      conn << "COMMIT;" if transaction
    rescue Sequel::DatabaseError
      conn << "ROLLBACK;" if transaction
      raise
    ensure
      conn << "SET statement_timeout TO 0" if timeout.present?
      @mutex.synchronize do
        @dbs_for_urls[url][:loaned].delete(t)
        @dbs_for_urls[url][:available] << Available.new(conn, Time.now)
      end
    end
    self.prune(url) if now > self.next_prune_at
    return result
  end

  def next_prune_at = self.last_pruned_at + self.prune_interval

  # Disconnect the cached connection for the given url,
  # if any. In general, this is only needed when tearing down a database.
  def disconnect(url)
    raise ArgumentError, "url cannot be blank" if url.blank?
    db_loans = @dbs_for_urls[url]
    return if db_loans.nil?
    if db_loans[:loaned].size.positive?
      raise Webhookdb::InvalidPrecondition,
            "url #{displaysafe_url(url)} still has #{db_loans[:loaned].size} active connections"
    end
    db_loans[:available].each(&:disconnect)
    @dbs_for_urls.delete(url)
  end

  protected def prune(skip_url)
    @dbs_for_urls.each do |url, db_loans|
      next false if url == skip_url
      db_loans[:available].each(&:disconnect)
    end
    self.last_pruned_at = Time.now
  end

  def force_disconnect_all
    @dbs_for_urls.each_value do |db_loans|
      db_loans[:available].each(&:disconnect)
      db_loans[:loaned].each_value(&:disconnect)
    end
    @dbs_for_urls.clear
  end

  def summarize
    return self.dbs_for_urls.transform_values do |loans|
      {loaned: loans[:loaned].size, available: loans[:available].size}
    end
  end
end

Webhookdb::ConnectionCache._instance = Webhookdb::ConnectionCache.new(
  prune_interval: Webhookdb::ConnectionCache.prune_interval,
)
