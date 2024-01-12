# frozen_string_literal: true

require "grape"

require "webhookdb/api"
require "webhookdb/postgres"

# Health check and other metadata endpoints.
class Webhookdb::API::System < Webhookdb::Service
  format :json

  require "webhookdb/service/helpers"
  helpers Webhookdb::Service::Helpers

  get :healthz do
    # Do not bother looking at dependencies like databases.
    # If the primary is down, we can still accept webhooks
    # if LoggedWebhook resiliency is configured,
    # which is the primary thing about whether we're healthy or not.
    status 200
    {o: "k"}
  end

  get :statusz do
    status 200
    {
      env: Webhookdb::RACK_ENV,
      version: Webhookdb::VERSION,
      commit: Webhookdb::COMMIT,
      release: Webhookdb::RELEASE,
      log_level: Webhookdb.logger.level,
    }
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
