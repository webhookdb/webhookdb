# frozen_string_literal: true

require "webhookdb/api"
require "webhookdb/demo_mode"

class Webhookdb::API::Auth < Webhookdb::API::V1
  include Webhookdb::Service::Types

  resource :auth do
    helpers do
      def guard_logged_in!
        c = current_customer?
        return if c.nil?
        merror!(403, "You are already logged in as #{c.email}. You must log out first.", code: "already_logged_in")
      end
    end

    helpers do
      def finish_auth(me)
        set_customer(me) if me
        extras = {}
        extras[:current_customer] = Webhookdb::API::CurrentCustomerEntity.represent(me).as_json if me
        return extras
      end
    end

    params do
      optional :email,
               type: String,
               coerce_with: NormalizedEmail,
               prompt: {
                 message: "Welcome to WebhookDB!\nPlease enter your email:",
                 demo_mode_proc: ->(r) { r.params[:email] = "demo@webhookdb.com" },
               }
      optional :token, type: String
    end
    post do
      message = ""
      if Webhookdb::DemoMode.client_enabled?
        membership, step, message = Webhookdb::DemoMode.handle_auth
        me = membership.customer
        extras = finish_auth(me)
        status 200
      elsif params[:token].blank?
        guard_logged_in!
        begin
          step, _ = Webhookdb::Customer.register_or_login(email: params[:email])
        rescue Webhookdb::Customer::SignupDisabled
          merror!(402, "Sorry, new signups are currently disabled.", code: "signup_disabled")
        end
        extras = {}
        status 202
      else
        guard_logged_in!
        step, me = Webhookdb::Customer.finish_otp(
          Webhookdb::Customer[email: params[:email]], token: params[:token],
        )
        extras = finish_auth(me)
        status 200
      end
      present step, with: Webhookdb::API::StateMachineEntity, extras:, message:
    end

    resource :login_otp do
      route_param :opaque_id do
        desc "Verify the OTP and auth the customer"
        params do
          requires :value
        end
        post do
          guard_logged_in!
          step, me = Webhookdb::Customer.finish_otp(
            Webhookdb::Customer[opaque_id: params[:opaque_id]], token: params[:value],
          )
          extras = finish_auth(me)
          status 200
          present step, with: Webhookdb::API::StateMachineEntity, extras:
        end
      end
    end

    post :logout do
      delete_session_cookies
      status 200
      present({}, with: Webhookdb::API::BaseEntity, message: "You have logged out.")
    end

    params do
      requires :form_name, type: String
      optional :email, type: String
      optional :name, type: String
      optional :message, type: String
    end
    post :contact do
      fields = []
      fields << {title: "Form", value: params[:form_name], short: true}
      fields << {title: "IP", value: request.ip, short: true}
      fields << {title: "User Agent", value: request.user_agent || "", short: false}
      if (email = params[:email])
        fields << {title: "Email", value: email, short: true}
      end
      if (name = params[:name])
        fields << {title: "Name", value: name, short: true}
      end
      if (msg = params[:message])
        fields << {title: "Message", value: msg, short: false}
      end

      Webhookdb::DeveloperAlert.new(
        subsystem: "New Contact",
        emoji: ":mailbox_with_mail:",
        fallback: fields.
          map { |f| "#{f[:title]}: #{f[:value]}" }.
          join(", "),
        fields:,
      ).emit

      status 200
      present({message: "ok"})
    end
  end
end
