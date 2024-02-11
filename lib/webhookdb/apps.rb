# frozen_string_literal: true

require "grape"
require "grape-swagger"
require "sidekiq/web"
require "sidekiq/cron/web"

require "webhookdb/api"
require "webhookdb/async"
require "webhookdb/sentry"
require "webhookdb/service"

require "webhookdb/api/auth"
require "webhookdb/api/db"
require "webhookdb/api/demo"
require "webhookdb/api/install"
require "webhookdb/api/me"
require "webhookdb/api/organizations"
require "webhookdb/api/replay"
require "webhookdb/api/saved_queries"
require "webhookdb/api/saved_views"
require "webhookdb/api/service_integrations"
require "webhookdb/api/services"
require "webhookdb/api/stripe"
require "webhookdb/api/subscriptions"
require "webhookdb/api/sync_targets"
require "webhookdb/api/system"
require "webhookdb/api/webhook_subscriptions"

require "webhookdb/admin_api/auth"
require "webhookdb/admin_api/customers"
require "webhookdb/admin_api/database_documents"
require "webhookdb/admin_api/message_deliveries"
require "webhookdb/admin_api/roles"

require "webterm/apps"

module Webhookdb::Apps
  # Call this from your rackup file, like config.ru.
  #
  # @example
  # lib = File.expand_path("lib", __dir__)
  # $LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
  # require "webhookdb"
  # Webhookdb.load_app
  # require "webhookdb/apps"
  # Webhookdb::Apps.rack_up(self)
  #
  def self.rack_up(config_ru)
    Webhookdb::Async.setup_web
    config_ru.instance_exec do
      map "/admin" do
        run Webhookdb::Apps::AdminAPI.build_app
      end
      map "/sidekiq" do
        run Webhookdb::Apps::SidekiqWeb.to_app
      end
      map "/terminal" do
        run Webhookdb::Apps::Webterm.to_app
      end
      run Webhookdb::Apps::API.build_app
    end
  end

  class API < Webhookdb::Service
    mount Webhookdb::API::Auth
    mount Webhookdb::API::Db
    mount Webhookdb::API::Demo
    mount Webhookdb::API::Install
    mount Webhookdb::API::Me
    mount Webhookdb::API::Organizations
    mount Webhookdb::API::Replay
    mount Webhookdb::API::SavedQueries
    mount Webhookdb::API::SavedViews
    mount Webhookdb::API::ServiceIntegrations
    mount Webhookdb::API::Services
    mount Webhookdb::API::Stripe
    mount Webhookdb::API::Subscriptions
    mount Webhookdb::API::SyncTargets
    mount Webhookdb::API::System
    mount Webhookdb::API::WebhookSubscriptions
    add_swagger_documentation if ENV["RACK_ENV"] == "development"
  end

  class AdminAPI < Webhookdb::Service
    mount Webhookdb::AdminAPI::Auth
    mount Webhookdb::AdminAPI::DatabaseDocuments
    mount Webhookdb::AdminAPI::MessageDeliveries
    mount Webhookdb::AdminAPI::Roles
    mount Webhookdb::AdminAPI::Customers
    add_swagger_documentation if ENV["RACK_ENV"] == "development"
  end

  SidekiqWeb = Rack::Builder.new do
    use Sentry::Rack::CaptureExceptions if Webhookdb::Sentry.enabled?
    use Rack::Auth::Basic, "Protected Area" do |username, password|
      # Protect against timing attacks: (https://codahale.com/a-lesson-in-timing-attacks/)
      # - Use & (do not use &&) so that it doesn't short circuit.
      # - Use digests to stop length information leaking
      Rack::Utils.secure_compare(
        ::Digest::SHA256.hexdigest(username),
        ::Digest::SHA256.hexdigest(Webhookdb::Async.web_username),
      ) & Rack::Utils.secure_compare(
        ::Digest::SHA256.hexdigest(password),
        ::Digest::SHA256.hexdigest(Webhookdb::Async.web_password),
      )
    end
    use Rack::Session::Cookie, secret: Webhookdb::Service.session_secret, same_site: true, max_age: 86_400
    run Sidekiq::Web
  end

  Webterm = Rack::Builder.new do
    use(Rack::SslEnforcer, {redirect_html: false}) if Webhookdb::Webterm.enforce_ssl
    use Rack::Deflater
    use Rack::ConditionalGet
    use Rack::ETag
    map "/" do
      use Webhookdb::Webterm::RedirectIndexHtmlToRoot
      use Webhookdb::Webterm::ServeIndexHtmlFromRoot
      run Webhookdb::Webterm::Files
    end
  end
end
