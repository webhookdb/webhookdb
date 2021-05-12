# frozen_string_literal: true

require "grape"

require "webhookdb/api"
require "webhookdb/admin_api"

class Webhookdb::API::Organizations < Webhookdb::API::V1
  resource :organizations do
    desc "Return all organizations associated with customer"
    params do
      requires :customer_id, type: String
    end
    get do
      customer = Webhookdb::Customer[params[:customer_id]]
      org_ids = customer.organization_memberships_dataset.select(:organization_id)
      orgs = Webhookdb::Organization.where(id: org_ids).all
      if orgs.empty?
        present({}, with: Webhookdb::AdminAPI::BaseEntity,
                    message: "You aren't affiliated with any organizations yet.",)
      else
        present orgs, with: Webhookdb::AdminAPI::OrganizationEntity
      end
    end

    resource :members do
      desc "Return all customers associated with organization"
      params do
        requires :customer_id, type: String
        requires :organization_id, type: String
      end
      get do
        request_customer = Webhookdb::Customer[params[:customer_id]]
        request_membership = request_customer.organization_memberships_dataset[organization_id: params[:organization_id]]
        if request_membership.nil?
          status 403
          present({}, with: Webhookdb::AdminAPI::BaseEntity,
                      message: "You don't have permissions with that organization.",)
        else
          org_memberships = Webhookdb::OrganizationMembership.where(organization_id: params[:organization_id]).all
          data = []
          org_memberships.each do |om|
            # TODO: Add indicator here
            data.push(Webhookdb::Customer.where(id: om.customer_id).first)
          end
          present data, with: Webhookdb::API::CLICustomerEntity
        end
      end
    end
  end
end
