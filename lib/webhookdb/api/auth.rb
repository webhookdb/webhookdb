# frozen_string_literal: true

require "grape"
require "name_of_person"

require "webhookdb/api"

class Webhookdb::API::Auth < Webhookdb::API::V1
  ALL_TIMEZONES = Set.new(TZInfo::Timezone.all_identifiers)

  resource :auth do
    desc "Log in using phone and password"
    params do
      optional :phone, us_phone: true, allow_blank: false
      optional :email, allow_blank: false
      exactly_one_of :phone, :email
      requires :password, type: String, allow_blank: false
    end
    post do
      if current_customer?
        env["warden"].logout
        env["warden"].clear_strategies_cache!
      end
      customer = authenticate!
      status 200
      present customer, with: Webhookdb::API::CurrentCustomerEntity, env: env
    end

    desc "Verify the current customer phone number using the given token"
    params do
      requires :token
    end
    post :verify do
      me = current_customer
      begin
        Webhookdb::Customer::ResetCode.use_code_with_token(params[:token]) do |code|
          invalid!("Invalid verification code") unless code.customer === me
          code.verify
          code.customer.save_changes
          me.refresh
        end
      rescue Webhookdb::Customer::ResetCode::Unusable
        invalid!("Invalid verification code")
      end

      status 200
      present me, with: Webhookdb::API::CurrentCustomerEntity, env: env
    end

    params do
      requires :transport, values: ["sms", "email"]
    end
    post :resend_verification do
      me = current_customer
      me.db.transaction do
        me.reset_codes_dataset.where(transport: params[:transport]).usable.each(&:expire!)
        me.add_reset_code(transport: params[:transport])
      end
      body ""
      status 204
    end

    delete do
      # Nope, cannot do this through Warden easily.
      # And really we should have server-based sessions we can expire,
      # but in the meantime, stomp on the cookie hard.
      options = env[Rack::RACK_SESSION_OPTIONS]
      options[:drop] = true

      # Rack sends a cookie with an empty session, but let's tell the browser to actually delete the cookie.
      cookies.delete(Webhookdb::Service::SESSION_COOKIE, domain: options[:domain], path: options[:path])

      status 204
      body ""
    end
  end
end
