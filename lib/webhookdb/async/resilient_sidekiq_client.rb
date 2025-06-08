# frozen_string_literal: true

require "webhookdb/async"
require "webhookdb/resilient_action"

class Webhookdb::Async::ResilientSidekiqClient < Sidekiq::Client
  alias _native_raw_push raw_push

  private def raw_push(payloads)
    Resilient.new(self).insert(payloads, {})
  end

  def self.resilient_replay
    pool = Thread.current[:sidekiq_via_pool] || Sidekiq.redis_pool
    self.new(pool).resilient.replay
  end

  def resilient = Resilient.new(self)

  class Resilient < Webhookdb::ResilientAction
    def initialize(client)
      @client = client
      super()
    end

    def logger = Webhookdb::Async.logger
    def database_urls = Webhookdb::LoggedWebhook.available_resilient_database_urls
    def rescued_exception_types = [Redis::ConnectionError]
    def do_insert(kwargs, _meta) = @client._native_raw_push(kwargs)
    def table_name = Webhookdb::LoggedWebhook.resilient_jobs_table_name
    def ping = @client.redis_pool.with(&:ping)

    def do_replay(kwargs, _meta)
      @client._native_raw_push(kwargs)
    end
  end
end
