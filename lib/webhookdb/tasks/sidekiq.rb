# frozen_string_literal: true

require "rake/tasklib"

require "webhookdb"

module Webhookdb::Tasks
  class Sidekiq < Rake::TaskLib
    def initialize
      super
      namespace :sidekiq do
        desc "Tag the Sidekiq deployment in metrics."
        task :release do
          require "sidekiq/deploy"
          require "webhookdb/async"
          url = Webhookdb::Redis.fetch_url(Webhookdb::Async.sidekiq_redis_provider, Webhookdb::Async.sidekiq_redis_url)
          # Use our own pool since we may need custom params for SSL reasons.
          pool = ::Sidekiq::RedisConnection.create(Webhookdb::Redis.conn_params(url, size: 1))
          ::Sidekiq::Deploy.new(pool).mark!(label: Webhookdb::RELEASE)
        end

        desc "Clear the Sidekiq redis DB (flushdb). " \
             "Only use on local, and only for legit reasons, " \
             "not to paper over problems that will show on staging and prod " \
             "(like removing a job class)."
        task :reset do
          require "webhookdb/async"
          ::Sidekiq.redis(&:flushdb)
        end

        desc "Run retry on all jobs in the retry set."
        task :retry_all do
          ::Sidekiq::RetrySet.new.retry_all
        end

        desc "Run retry on all jobs in the dead set."
        task :retry_all_dead do
          ::Sidekiq::DeadSet.new.retry_all
        end
      end
    end
  end
end
