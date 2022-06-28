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
class Webhookdb::ConnectionCache
  include Appydays::Configurable
  include Appydays::Loggable
  extend Webhookdb::MethodUtilities
  include Webhookdb::Dbutil

  configurable(:connection_cache) do
    # If this many seconds has elapsed since the last connecton was borrowed,
    # prune connections with no pending borrows.
    setting :prune_interval, 120
  end

  singleton_attr_accessor :_instance

  def self.borrow(url, &)
    return self._instance.borrow(url, &)
  end

  def self.disconnect(url)
    self._instance.disconnect(url)
  end

  attr_accessor :databases, :prune_interval, :last_pruned_at

  def initialize(prune_interval:)
    @databases = {}
    @prune_interval = prune_interval
    @last_pruned_at = Time.now
  end

  # Connect to the database at the given URL
  # (or reuse existing connection),
  # and yield the database to the given block.
  # See class docs for more details.
  def borrow(url, &block)
    raise LocalJumpError if block.nil?
    raise ArgumentError, "url cannot be blank" if url.blank?
    now = Time.now
    url_cache = @databases[url]
    if url_cache.nil?
      db = take_conn(url, extensions: [:pg_json])
      url_cache = {pending: 1, connection: db}
      @databases[url] = url_cache
    else
      url_cache[:pending] += 1
    end
    begin
      result = yield url_cache[:connection]
    ensure
      url_cache[:pending] -= 1
    end
    self.prune(url) if now > self.next_prune_at
    return result
  end

  def next_prune_at = self.last_pruned_at + self.prune_interval

  # Disconnect the cached connection for the given url,
  # if any. In general, this is only needed when tearing down a database.
  def disconnect(url)
    raise ArgumentError, "url cannot be blank" if url.blank?
    url_cache = @databases[url]
    return if url_cache.nil?
    if url_cache[:pending].positive?
      raise Webhookdb::InvalidPrecondition,
            "url #{displaysafe_url(url)} still has #{url_cache[:pending]} active connections"

    end
    db = url_cache[:connection]
    db.disconnect
    @databases.delete(url)
  end

  protected def prune(skip_url)
    @databases.delete_if do |url, url_cache|
      next false if url_cache[:pending].positive?
      next if url == skip_url
      if url_cache[:pending].negative?
        raise "invariant violation: url_cache pending is negative: " \
              "#{displaysafe_url(url)}, #{url_cache.inspect}"
      end
      url_cache[:connection].disconnect
      true
    end
    self.last_pruned_at = Time.now
  end
end

Webhookdb::ConnectionCache._instance = Webhookdb::ConnectionCache.new(
  prune_interval: Webhookdb::ConnectionCache.prune_interval,
)
