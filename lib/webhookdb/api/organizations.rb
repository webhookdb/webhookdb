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
  end
  end
