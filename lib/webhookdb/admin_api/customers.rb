# frozen_string_literal: true

require "grape"

require "webhookdb/admin_api"

class Webhookdb::AdminAPI::Customers < Webhookdb::AdminAPI::V1
  resource :customers do
    desc "Return all customers, newest first"
    params do
      use :pagination
      use :ordering, model: Webhookdb::Customer
      use :searchable
    end
    get do
      ds = Webhookdb::Customer.dataset
      if (email_like = search_param_to_sql(params, :email))
        name_like = search_param_to_sql(params, :name)
        ds = ds.where(email_like | name_like)
      end

      ds = order(ds, params)
      ds = paginate(ds, params)
      present_collection ds, with: Webhookdb::AdminAPI::CustomerEntity
    end

    route_param :id, type: Integer do
      desc "Return the customer"
      get do
        (customer = Webhookdb::Customer[params[:id]]) or not_found!
        present customer, with: Webhookdb::AdminAPI::DetailedCustomerEntity
      end

      desc "Update the customer"
      params do
        optional :name, type: String
        optional :note, type: String
        optional :email, type: String
        optional :roles, type: Array[String]
      end
      post do
        fields = params
        (customer = Webhookdb::Customer[fields[:id]]) or not_found!
        customer.db.transaction do
          if (roles = fields.delete(:roles))
            customer.remove_all_roles
            roles.uniq.each { |r| customer.add_role(Webhookdb::Role[name: r]) }
          end
          if fields.key?(:email_verified)
            customer.email_verified_at = fields.delete(:email_verified) ? Time.now : nil
          end
          if fields.key?(:phone_verified)
            customer.phone_verified_at = fields.delete(:phone_verified) ? Time.now : nil
          end
          set_declared(customer, params)
          customer.save_changes
        end
        status 200
        present customer, with: Webhookdb::AdminAPI::DetailedCustomerEntity
      end
    end
  end
end
