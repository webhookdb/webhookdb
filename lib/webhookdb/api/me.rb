# frozen_string_literal: true

require "grape"

require "webhookdb/api"

class Webhookdb::API::Me < Webhookdb::API::V1
  resource :me do
    desc "Return the current customer"
    get do
      customer = current_customer
      present customer, with: Webhookdb::API::CurrentCustomerEntity, env: env
    end

    desc "Update supported fields on the customer"
    params do
      optional :email, type: String, allow_blank: false
      optional :first_name, type: String, allow_blank: false
      optional :last_name, type: String, allow_blank: false
    end
    post :update do
      customer = current_customer
      set_declared(customer, params)
      save_or_error!(customer)

      status 200
      present customer, with: Webhookdb::API::CurrentCustomerEntity
    end

    desc "Change the current customer password"
    params do
      requires :current_password, type: String, allow_blank: false
      requires :new_password, type: String, allow_blank: false
    end
    post :password do
      customer = current_customer
      if customer.password_digest != Webhookdb::Customer::PLACEHOLDER_PASSWORD_DIGEST
        pass_matches = customer.authenticate(params[:current_password])
        merror!(400, "Sorry, that current password isn't correct.") unless pass_matches
      end

      customer.db.transaction do
        customer.password = params[:new_password]
        save_or_error!(customer)
        customer.reset_codes_dataset.usable.each(&:expire!)
      end

      status 200
      present customer, with: Webhookdb::API::CurrentCustomerEntity
    end

    desc "Initiate the process for when a customer forgets their password"
    params do
      optional :phone, us_phone: true, allow_blank: false
      optional :email, allow_blank: false
      exactly_one_of :phone, :email
    end
    post :forgot_password do
      merror!(403, "You are already logged in", code: "forbidden") if
        current_customer?

      body = {}

      if params[:phone].present?
        (customer = Webhookdb::Customer.with_us_phone(params[:phone])) or
          merror!(403, "No customer with that phone", code: "not_found")
        customer.add_reset_code(transport: "sms")
        body[:phone] = customer.us_phone
      else
        (customer = Webhookdb::Customer.with_email(params[:email])) or
          merror!(403, "No customer with that email", code: "not_found")
        customer.add_reset_code(transport: "email")
        body[:email] = customer.email
      end

      status 202
      present body
    end

    desc "Check that the password reset token is valid, for 2-stage reset"
    params do
      requires :token, type: String, allow_blank: false
    end
    post :reset_password_check do
      forbidden! if current_customer?

      invalid = Webhookdb::Customer::ResetCode.usable.where(token: params[:token]).empty?
      status 200
      h = {valid: !invalid}
      present h
    end

    desc "Reset the password of the customer with the code"
    params do
      requires :token, type: String, allow_blank: false, desc: "The unique password reset token"
      requires :password, type: String, allow_blank: false, desc: "The new password for the customer"
    end
    post :reset_password do
      forbidden! if current_customer?

      customer = nil
      begin
        customer = Webhookdb::Customer::ResetCode.use_code_with_token(params[:token]) do |code|
          code.customer.password = params[:password]
          if code.transport == "sms"
            code.customer.verify_phone
          else
            code.customer.verify_email
          end
          code.customer.save_changes
          code.customer
        end
      rescue Webhookdb::Customer::ResetCode::Unusable
        forbidden!
      end

      set_customer(customer)
      status 200
      present customer, with: Webhookdb::API::CurrentCustomerEntity
    end

    segment :settings do
      get do
        present current_customer, with: Webhookdb::API::CustomerSettingsEntity
      end

      params do
        optional :first_name, type: String, allow_blank: false
        optional :last_name, type: String, allow_blank: false
      end
      patch do
        c = current_customer
        c.db.transaction do
          set_declared(c, params)
          save_or_error!(c)
        end

        status 200
        present c, with: Webhookdb::API::CustomerSettingsEntity
      end
    end
  end
end
