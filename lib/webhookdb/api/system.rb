# frozen_string_literal: true

require "grape"

require "webhookdb/api"
require "webhookdb/postgres"

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

  desc "Return more extensive health information about service dependencies."
  get :service_health do
    result = {
      db: -1,
      redis: -1,
      autoscale_started: Time.at(0),
      autoscale_depth: -1,
    }
    begin
      start = Time.now
      Webhookdb::Customer.db["SELECT 1"]
      result[:db] = (Time.now - start).to_f
    rescue StandardError
      nil
    end
    begin
      Sidekiq.redis do |c|
        start = Time.now
        c.ping
        result[:redis] = (Time.now - start).to_f
        result[:autoscale_started] = Time.at(c.get("amigo/autoscaler/latency_event_started").to_i).utc.iso8601
        result[:autoscale_depth] = c.get("amigo/autoscaler/depth").to_i
      end
    rescue StandardError
      nil
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
