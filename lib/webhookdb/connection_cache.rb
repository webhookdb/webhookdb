# frozen_string_literal: true

require "appydays/configurable"
require "appydays/loggable"

require "webhookdb"

# Because making new connections are costly,
# we don't *always* want to do them.
# But unless we disconnect them, we create a memory leak
# (see https://sequel.jeremyevans.net/rdoc/files/doc/opening_databases_rdoc.html).
# To get around this, we use an in-memory LRU cache.
# Each host has its own cache.
# The keys are connection strings.
# Connections are borrowed for a block.
# When a new connection is borrowed,
# we throw out any connections with no pending borrows.
class Webhookdb::ConnectionCache
  include Appydays::Configurable
  include Appydays::Loggable
  extend Webhookdb::MethodUtilities

  configurable(:connection_cache) do
    setting :max_connections_per_host, 20
  end

  singleton_attr_accessor :_instance

  def self.borrow(url, &block)
    return self._instance.borrow(url, &block)
  end

  def self.disconnect(url)
    self._instance.disconnect(url)
  end

  def initialize
    @cache = {}
  end

  def borrow(url, &block)
    raise LocalJumpError if block.nil?
    raise ArgumentError, "url cannot be blank" if url.blank?
    uri = URI(url)
    host_cache = @cache[uri.host] ||= {}
    url_cache = host_cache[url]
    if url_cache.nil?
      db = Sequel.connect(url)
      db.extension :pg_json
      url_cache = {pending: 0, connection: db}
      host_cache[url] = url_cache
    end
    url_cache[:pending] += 1
    self.prune
    begin
      result = yield url_cache[:connection]
    ensure
      url_cache[:pending] -= 1
    end
    return result
  end

  def disconnect(url)
    raise ArgumentError, "url cannot be blank" if url.blank?
    uri = URI(url)
    host_cache = @cache[uri.host] ||= {}
    url_cache = host_cache[url]
    return if url_cache.nil?
    raise Webhookdb::InvalidPrecondition, "url #{url} still have #{url_cache[:pending]} active connections" if
      url_cache[:pending].positive?
    db = url_cache[:connection]
    db.disconnect
    Sequel.synchronize { Sequel::DATABASES.delete(db) }
    host_cache.delete(url)
  end

  protected def prune
    @cache.each do |host_cache|
      remaining_to_remove = host_cache.length - self.class.max_connections_per_host
      while remaining_to_remove.positive?
        url, url_cache = host_cache.find { |_k, v| v[:pending].zero? }
        break if url_cache.nil?
        db = url_cache[:connection]
        db.disconnect
        Sequel.synchronize { Sequel::DATABASES.delete(db) }
        host_cache.delete(url)
        remaining_to_remove -= 1
      end
    end
  end
end

Webhookdb::ConnectionCache._instance = Webhookdb::ConnectionCache.new
