# frozen_string_literal: true

require "rack/cors"
require "rack/protection"
require "rack/ssl-enforcer"
require "sentry-ruby"
require "appydays/loggable/request_logger"

require "webhookdb/service" unless defined?(Webhookdb::Service)

module Webhookdb::Service::Middleware
  def self.add_middlewares(builder)
    self.add_cors_middleware(builder)
    self.add_common_middleware(builder)
    self.add_dev_middleware(builder) if Webhookdb::Service.devmode
    self.add_ssl_middleware(builder) if Webhookdb::Service.enforce_ssl
    self.add_session_middleware(builder)
    self.add_security_middleware(builder)
    Webhookdb::Service::Auth.add_warden_middleware(builder)
    builder.use(RequestLogger)
  end

  def self.add_cors_middleware(builder)
    builder.use(Rack::Cors) do
      allow do
        origins(*Webhookdb::Service.cors_origins)
        resource "*", headers: :any, methods: :any, credentials: true
      end
    end
  end

  def self.add_common_middleware(builder)
    builder.use(Rack::ContentLength)
    builder.use(Rack::Chunked)
    builder.use(Sentry::Rack::CaptureExceptions)
  end

  def self.add_dev_middleware(builder)
    builder.use(Rack::ShowExceptions)
    builder.use(Rack::Lint)
  end

  def self.add_ssl_middleware(builder)
    builder.use(Rack::SslEnforcer, redirect_html: false)
  end

  ### Add middleware for maintaining sessions to +builder+.
  def self.add_session_middleware(builder)
    builder.use Rack::Session::Cookie, Webhookdb::Service.cookie_config
    builder.use(SessionReader)
  end

  ### Add security middleware to +builder+.
  def self.add_security_middleware(_builder)
    # session_hijacking causes issues in integration tests...?
    # builder.use Rack::Protection, except: :session_hijacking
  end

  # We always want a session to be written, even if noop requests,
  # so always force a write if the session isn't loaded.
  class SessionReader
    def initialize(app)
      @app = app
    end

    def call(env)
      env["rack.session"]["_"] = "_" unless env["rack.session"].loaded?
      @app.call(env)
    end
  end

  class RequestLogger < Appydays::Loggable::RequestLogger
    def request_tags(env)
      tags = super
      tags[:customer_id] = env["warden"].user(:customer)&.id || 0
      return tags
    end
  end
end
