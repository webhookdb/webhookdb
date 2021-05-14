# frozen_string_literal: true

require "grape"

require "webhookdb/api"
require "webhookdb/admin_api"

class Webhookdb::API::Organizations < Webhookdb::API::V1
  helpers do
    def lookup_org!
      customer = current_customer
      membership = customer.memberships_dataset[organization_id: params[:organization_id], verified: true]
      merror!(403, "You don't have permissions with that organization.") if membership.nil?
      return membership.organization
    end

    def ensure_admin!
      customer = current_customer
      org = lookup_org!
      admin_membership = org.memberships_dataset[customer: customer, role: Webhookdb::OrganizationRole.admin_role]
      merror!(400, "Permission denied: You don't have admin privileges with #{org.name}.") if admin_membership.nil?
    end
  end

  resource :organizations do
    desc "Return all organizations the customer is part of."
    get do
      customer = current_customer
      orgs = Webhookdb::Organization.where(memberships: customer.memberships_dataset).all
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

      # POST

      resource :invite do
        desc "Generates an invitation code for a user, adds pending membership in the organization."
        params do
          requires :email, type: String, allow_blank: false
        end
        post do
          customer = current_customer
          org = lookup_org!
          customer.db.transaction do
            if Webhookdb::Customer[email: params[:email]].nil?
              Webhookdb::Customer.create(email: params[:email], password: SecureRandom.hex(8))
            end
            invitee = Webhookdb::Customer[email: params[:email]]
            merror!(400, "That person is already a member of the organization.") if invitee.member_of?(org)
            invitation_code = "join-" + SecureRandom.hex(4)
            membership = org.add_membership(customer: invitee, verified: false, invitation_code: invitation_code)
            message = "An invitation has been sent to #{params[:email]}. Their invite code is: \n #{invitation_code}"
            present membership, with: Webhookdb::API::OrganizationMembershipEntity, message: message
          end
        end
      end

      resource :remove do
        desc "Allows organization admin to remove customer from an organization"
        params do
          requires :email, type: String, allow_blank: false
        end
        post do
          customer = current_customer
          org = lookup_org!
          ensure_admin!
          customer.db.transaction do
            to_delete = org.memberships_dataset.where(customer: Webhookdb::Customer[email: params[:email]])
            merror!(400, "That user is not a member of #{org.name}.") if to_delete.empty?
            to_delete.delete
            present({}, with: Webhookdb::AdminAPI::BaseEntity,
                        message: "#{params[:email]} is no longer a part of the Lithic Technology organization.",)
          end
        end
      end

      resource :change_roles do
        desc "Allows organization admin to change customer's role in an organization"
        params do
          requires :emails, type: Array[String]
          requires :role_name, type: String
        end
        post do
          customer = current_customer
          org = lookup_org!
          ensure_admin!
          customer.db.transaction do
            new_role = Webhookdb::OrganizationRole.find_or_create_or_find(name: params[:role_name])
            memberships = org.memberships_dataset.where(customer: Webhookdb::Customer.where(email: params[:emails]))
            memberships.update(role_id: new_role.id)
            merror!(400, "Those emails do not belong to members of #{org.name}.") if memberships.empty?
            message = "Success! These users have now been assigned the role of #{new_role.name} in #{org.name}."
            present memberships.all, with: Webhookdb::API::OrganizationMembershipEntity, message: message
          end
        end
      end
    end

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
          # TODO: Create & send email with invitation code
          # TODO: if membership exists but is not verified, maybe resend with new join code
        end
      end
    end

    resource :join do
      desc "Allows user to verify membership in an organization with an invitation code."
      params do
        requires :invitation_code, type: String, allow_blank: false
      end
      post do
        customer = current_customer
        customer.db.transaction do
          membership = customer.memberships_dataset[invitation_code: params[:invitation_code]]
          merror!(400, "Looks like that invite code is invalid. Please try again.") if membership.nil?
          membership.verified = true
          message = "Congratulations! You are now a member of #{membership.organization_name}."
          present membership, with: Webhookdb::API::OrganizationMembershipEntity, message: message
        end
      end
    end
  end
end
