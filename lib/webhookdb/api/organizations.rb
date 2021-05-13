# frozen_string_literal: true

require "grape"

require "webhookdb/api"
require "webhookdb/admin_api"

class Webhookdb::API::Organizations < Webhookdb::API::V1
  helpers do
    def lookup_org!
      customer = current_customer
      membership = customer.organization_memberships_dataset[organization_id: params[:organization_id]]
      merror!(403, "You don't have permissions with that organization.") if membership.nil?
      return membership.organization
    end
  end

  resource :organizations do
    desc "Return all organizations the customer is part of."
    get do
      customer = current_customer
      orgs = Webhookdb::Organization.where(memberships: customer.organization_memberships_dataset).all
      message = orgs.empty? ? "You aren't affiliated with any organizations yet." : ""
      present_collection orgs, with: Webhookdb::API::OrganizationEntity, message: message
    end

    # GET

    route_param :organization_id, type: Integer do
      resource :members do
        desc "Return all customers associated with the organization"
        get do
          org_memberships = lookup_org!.memberships
          present_collection org_memberships, with: Webhookdb::API::OrganizationMembershipEntity
        end
      end

      resource :service_integrations do
        desc "Return all integrations associated with the organization."
        get do
          integrations = lookup_org!.service_integrations
          message = integrations.empty? ? "Organization doesn't have any integrations yet." : ""
          present_collection integrations, with: Webhookdb::API::ServiceIntegrationEntity, message: message
        end
      end
    end

    # POST

    resource :create do
      desc "Creates a new organization and adds current customer as a member."
      params do
        requires :name, type: String, allow_blank: false
      end
      post do
        customer = current_customer
        customer.db.transaction do
          new_org = Webhookdb::Organization.create_if_unique(name: params[:name])
          merror!(400, "An organization with that name already exists.") if new_org.nil?
          new_org.add_membership(customer: customer)
          message = "Your organization identifier is: #{new_org.key} \n Use `webhookdb org invite <email>` " \
            "to invite members to #{new_org.name}."
          present new_org, with: Webhookdb::API::OrganizationEntity, message: message
        end
      end
    end
  end
  end
