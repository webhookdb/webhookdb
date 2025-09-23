# frozen_string_literal: true

require "grape"

require "webhookdb/api"
require "webhookdb/postgres"
require "webhookdb/async/autoscaler"
require "webhookdb/async/web_autoscaler"

# Health check and other metadata endpoints.
class Webhookdb::API::System < Webhookdb::Service
  format :json

  require "webhookdb/service/helpers"
  helpers Webhookdb::Service::Helpers

  get "/" do
    redirect "/terminal/"
  end

  get :healthz do
    # Do not bother looking at dependencies like databases.
    # If the primary is down, we can still accept webhooks
    # if LoggedWebhook resiliency is configured,
    # which is the primary thing about whether we're healthy or not.
    status 200
    {o: "k"}
  end

  helpers do
    def safe_call(&)
      yield
    rescue StandardError => e
      puts e if Webhookdb::RACK_ENV == "test"
      nil
    end
  end

  desc "Return more extensive health information about service dependencies."
  get :service_health do
    result = {
      db: -1,
      redis: -1,
      autoscale_started: Time.at(0),
      autoscale_depth: -1,
    }
    safe_call do
      start = Time.now
      Webhookdb::Customer.db["SELECT 1"]
      result[:db] = (Time.now - start).to_f
    end
    safe_call do
      Sidekiq.redis do |c|
        start = Time.now
        c.call("PING")
        result[:redis] = (Time.now - start).to_f
        ns = Webhookdb::Async::Autoscaler::NAMESPACE
        result[:autoscale_started] = Time.at(c.call("GET", "#{ns}/latency_event_started").to_i).utc.iso8601
        result[:autoscale_depth] = c.call("GET", "#{ns}/depth").to_i
      end
      result[:queues] = Sidekiq::Queue.all.map { |q| {n: q.name, l: q.latency} }
    end
    safe_call do
      Webhookdb::Redis.cache.with do |c|
        start = Time.now
        c.call("PING")
        result[:redis_cache] = (Time.now - start).to_f
        ns = Webhookdb::Async::WebAutoscaler::NAMESPACE
        result[:web_autoscale_started] = Time.at(c.call("GET", "#{ns}/latency_event_started").to_i).utc.iso8601
        result[:web_autoscale_depth] = c.call("GET", "#{ns}/depth").to_i
      end
    end
    status 200
    present(result)
  end

  get :statusz do
    status 200
    {
      env: Webhookdb::RACK_ENV,
      version: Webhookdb::VERSION,
      commit: Webhookdb::COMMIT,
      release: Webhookdb::RELEASE,
      released_at: Webhookdb::RELEASE_CREATED_AT,
      log_level: Webhookdb.logger.level,
    }
  end

  post :sink do
    status 204
    body ""
  end

  if ["development", "test"].include?(Webhookdb::RACK_ENV)
    resource :debug do
      resource :echo do
        [:get, :post, :patch, :put, :delete].each do |m|
          self.send(m) do
            pp params.to_h
            pp request.headers
            status 200
            present({})
          end
        end
      end
    end
  end
end
