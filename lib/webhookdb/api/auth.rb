# frozen_string_literal: true

require "grape"
require "name_of_person"

require "webhookdb/api"
require "webhookdb/organization_membership"

class Webhookdb::API::Auth < Webhookdb::API::V1
  include Webhookdb::Service::Types

  resource :auth do
    helpers do
      def guard_logged_in!
        return unless (c = current_customer?)
        merror!(403, "You are already logged in as #{c.email}. You must log out first", code: "already_logged_in")
      end
    end

    params do
      requires :email, type: String, allow_blank: false, coerce_with: NormalizedEmail
    end
    post do
      guard_logged_in!
      step, _ = Webhookdb::Customer.register_or_login(email: params[:email])
      status 202
      present step, with: Webhookdb::API::StateMachineEntity
    end

    resource :login_otp do
      route_param :opaque_id do
        desc "Verify the OTP and auth the customer"
        params do
          requires :value
        end
        post do
          guard_logged_in!
          step, me = Webhookdb::Customer.finish_otp(opaque_id: params[:opaque_id], token: params[:value])
          set_customer(me) if me
          status 200
          present step, with: Webhookdb::API::StateMachineEntity
        end
      end
    end

    post :logout do
      # Nope, cannot do this through Warden easily.
      # And really we should have server-based sessions we can expire,
      # but in the meantime, stomp on the cookie hard.
      options = env[Rack::RACK_SESSION_OPTIONS]
      options[:drop] = true

      # Rack sends a cookie with an empty session, but let's tell the browser to actually delete the cookie.
      cookies.delete(Webhookdb::Service::SESSION_COOKIE, domain: options[:domain], path: options[:path])

      status 200
      present({}, with: Webhookdb::API::BaseEntity, message: "You have logged out.")
    end
  end
end
