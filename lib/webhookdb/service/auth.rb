# frozen_string_literal: true

require "appydays/configurable"
require "warden"

class Webhookdb::Service::Auth
  include Appydays::Configurable

  class PasswordStrategy < Warden::Strategies::Base
    def valid?
      params["password"] && (params["phone"] || params["email"])
    end

    def authenticate!
      customer = self.lookup_customer
      success!(customer) if customer
    end

    protected def lookup_customer
      if params["phone"]
        customer = Webhookdb::Customer.with_us_phone(params["phone"].strip)
        if customer.nil?
          fail!("No customer with that phone")
          return nil
        end
      else
        customer = Webhookdb::Customer.with_email(params["email"].strip)
        if customer.nil?
          fail!("No customer with that email")
          return nil
        end
      end
      return customer if customer.authenticate(params["password"])
      fail!("Incorrect password")
      return nil
    end
  end

  class AdminPasswordStrategy < PasswordStrategy
    def authenticate!
      return unless (customer = self.lookup_customer)
      unless customer.admin?
        fail!
        return
      end
      success!(customer)
    end
  end

  # Create the middleware for a Warden auth failure.
  # Is not a 'normal' Rack middleware, which normally accepts 'app' in the initializer and has
  # 'call' as an instance method.
  # See https://github.com/wardencommunity/warden/wiki/Setup
  class FailureApp
    def self.call(env)
      warden_opts = env.fetch("warden.options", {})
      msg = warden_opts[:message] || env["webhookdb.authfailuremessage"] || "Unauthorized"
      body = Webhookdb::Service.error_body(401, msg)
      return 401, {"Content-Type" => "application/json"}, [body.to_json]
    end
  end

  # Middleware to use for Grape admin auth.
  # See https://github.com/ruby-grape/grape#register-custom-middleware-for-authentication
  class Admin
    def initialize(app, *_args)
      @app = app
    end

    def call(env)
      warden = env["warden"]
      customer = warden.authenticate!(scope: :admin)

      unless customer.admin?
        body = Webhookdb::Service.error_body(401, "Unauthorized")
        return 401, {"Content-Type" => "application/json"}, [body.to_json]
      end
      return @app.call(env)
    end
  end

  Warden::Manager.serialize_into_session(&:id)
  Warden::Manager.serialize_from_session { |id| Webhookdb::Customer[id] }

  Warden::Strategies.add(:password, PasswordStrategy)
  Warden::Strategies.add(:admin_password, AdminPasswordStrategy)

  # Restore the /unauthenticated route to what it originally was.
  # This is an API, not a rendered app...
  Warden::Manager.before_failure do |env, opts|
    env["PATH_INFO"] = opts[:attempted_path]
  end

  def self.add_warden_middleware(builder)
    builder.use Warden::Manager do |manager|
      # manager.default_strategies :password
      manager.failure_app = FailureApp

      manager.scope_defaults(:customer, strategies: [:password])
      manager.scope_defaults(:admin, strategies: [:admin_password])
    end
  end

  class Impersonation
    attr_reader :admin_customer, :warden

    def initialize(warden)
      @warden = warden
    end

    def is?
      return false unless self.warden.authenticated?(:admin)
      return self.warden.session(:admin)["impersonating"].present?
    end

    def on(target_customer)
      self.warden.session(:admin)["impersonating"] = target_customer.id
      self.warden.logout(:customer)
      self.warden.set_user(target_customer, scope: :customer)
    end

    def off(admin_customer)
      self.warden.logout(:customer)
      self.warden.session(:admin).delete("impersonating")
      self.warden.set_user(admin_customer, scope: :customer)
    end
  end
end
