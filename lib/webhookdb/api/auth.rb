# frozen_string_literal: true

require "grape"
require "name_of_person"

require "webhookdb/api"
require "webhookdb/organization_membership"

class Webhookdb::API::Auth < Webhookdb::API::V1
  resource :auth do
    helpers do
      def guard_logged_in!
        return unless (c = current_customer?)
        merror!(403, "You are already logged in as #{c.email}. You must log out first", code: "already_logged_in")
      end
    end

    params do
      requires :email, allow_blank: false
    end
    post do
      guard_logged_in!
      email = params[:email].strip.downcase
      unless (c = Webhookdb::Customer[email: email])
        self_org = Webhookdb::Organization.create(name: "Org for #{email}", billing_email: email.to_s)
        c = Webhookdb::Customer.create(email: email, password: SecureRandom.hex(16))
        c.add_membership(organization: self_org, role: Webhookdb::OrganizationRole.admin_role, verified: true)
      end
      c.reset_codes_dataset.usable.each(&:expire!)
      c.add_reset_code(transport: "email")
      status 202
      message = "Please check your email #{email} for a login code."
      present c, with: Webhookdb::API::CurrentCustomerEntity, env: env, message: message
    end

    desc "Auth the current customer via OTP"
    params do
      requires :email, allow_blank: false
      requires :token
    end
    post :login_otp do
      guard_logged_in!
      email = params[:email].strip.downcase
      (me = Webhookdb::Customer[email: email]) or merror!(403, "No customer with that email", code: "user_not_found")
      if me.should_skip_authentication?
        nil
      else
        begin
          Webhookdb::Customer::ResetCode.use_code_with_token(params[:token]) do |code|
            invalid!("Invalid verification code") unless code.customer === me
            code.customer.save_changes
            me.refresh
          end
        rescue Webhookdb::Customer::ResetCode::Unusable
          invalid!("Invalid verification code")
        end
      end

      set_customer(me)
      status 200
      present me, with: Webhookdb::API::CurrentCustomerEntity, env: env, message: "You are now logged in as #{email}"
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
