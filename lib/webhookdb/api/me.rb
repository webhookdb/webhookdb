# frozen_string_literal: true

require "grape"

require "webhookdb/api"

class Webhookdb::API::Me < Webhookdb::API::V1
  resource :me do
    desc "Return the current customer"
    get do
      customer = current_customer
      present customer, with: Webhookdb::API::CurrentCustomerEntity, env:
    end

    desc "Update supported fields on the customer"
    params do
      optional :name, type: String, allow_blank: false
    end
    post :update do
      customer = current_customer
      set_declared(customer, params)
      save_or_error!(customer)

      status 200
      present customer, with: Webhookdb::API::CurrentCustomerEntity
    end

    segment :settings do
      get do
        present current_customer, with: Webhookdb::API::CustomerSettingsEntity
      end

      params do
        optional :name, type: String, allow_blank: false
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
