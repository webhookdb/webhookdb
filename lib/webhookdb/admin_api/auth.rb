# frozen_string_literal: true

require "grape"

require "webhookdb/admin_api"

class Webhookdb::AdminAPI::Auth < Webhookdb::AdminAPI::V1
  resource :auth do
    desc "Return the current administrator customer."
    get do
      present admin_customer, with: Webhookdb::AdminAPI::CurrentCustomerEntity, env: env
    end

    resource :impersonate do
      desc "Remove any active impersonation and return the admin customer."
      delete do
        Webhookdb::Service::Auth::Impersonation.new(env["warden"]).off(admin_customer)

        status 200
        present admin_customer, with: Webhookdb::AdminAPI::CurrentCustomerEntity, env: env
      end

      route_param :customer_id, type: Integer do
        desc "Impersonate a customer"
        post do
          (target = Webhookdb::Customer[params[:customer_id]]) or not_found!

          Webhookdb::Service::Auth::Impersonation.new(env["warden"]).on(target)

          status 200
          present target, with: Webhookdb::AdminAPI::CurrentCustomerEntity, env: env
        end
      end
    end
  end
end
