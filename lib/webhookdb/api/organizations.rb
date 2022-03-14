# frozen_string_literal: true

require "grape"

require "webhookdb/api"
require "webhookdb/admin_api"

class Webhookdb::API::Organizations < Webhookdb::API::V1
  include Webhookdb::Service::Types

  resource :organizations do
    route_param :org_identifier, type: String do
      helpers do
        def check_self_role_modification!(email)
          return unless email == current_customer.email
          return if params.key?(:guard_confirm)
          Webhookdb::API::Helpers.prompt_for_required_param!(
            request,
            :guard_confirm,
            "WARNING: You are modifying your own permissions. Enter to proceed, or Ctrl+C to quit:",
          )
        end

        # If the current customer is the last admin of the org, we cannot allow them to remove themselves,
        # since the org would have no admins.
        def roll_back_if_no_admins!(org)
          has_admins = !org.memberships_dataset.
            where(membership_role: Webhookdb::Role.admin_role, verified: true).
            empty?
          return if has_admins
          msg = "Sorry, you are the last admin in #{org.name} and cannot remove yourself. " \
                "If you want to close down this org, Use 'webhookdb org close'"
          merror!(409, msg, code: "remove_last_admin", rollback_db: org.db)
        end
      end

      desc "Return organization with the given identifier."
      get do
        _customer = current_customer
        org = lookup_org!
        # create a nested object so that we can unmarshal the org as a single entity in the cli
        org_object = {organization: {id: org.id, name: org.name, key: org.key}}
        present org_object
      end

      resource :members do
        desc "Return all customers associated with the organization"
        get do
          org_memberships = lookup_org!.memberships
          present_collection org_memberships, with: Webhookdb::API::OrganizationMembershipEntity
        end
      end

      resource :services do
        desc "Returns a list of all available services."
        get do
          _customer = current_customer
          org = lookup_org!
          fake_entities = org.available_services.map { |name| {name:} }
          present_collection fake_entities, with: Webhookdb::API::ServiceEntity
        end
      end

      desc "Generates an invitation code for a user, adds pending membership in the organization."
      params do
        requires :email, type: String, allow_blank: false, coerce_with: NormalizedEmail,
                         prompt: "Enter the email to send the invitation to:"
      end
      post :invite do
        customer = current_customer
        org = lookup_org!
        ensure_admin!
        customer.db.transaction do
          # cannot use find_or_create_or_find here because all customers must be created with a random password,
          # which can't be included in find parameters
          if Webhookdb::Customer[email: params[:email]].nil?
            Webhookdb::Customer.create(email: params[:email], password: SecureRandom.hex(8))
          end
          invitee = Webhookdb::Customer[email: params[:email]]
          merror!(400, "That person is already a member of the organization.") if invitee.verified_member_of?(org)

          membership = Webhookdb::OrganizationMembership.find_or_create_or_find(
            organization: org, customer: invitee,
            verified: false,
          )
          # set/reset the code
          invitation_code = "join-" + SecureRandom.hex(4)
          Webhookdb::OrganizationMembership.where(id: membership.id).update(invitation_code:)

          Webhookdb.publish("webhookdb.organizationmembership.invite", membership.id)
          message = "An invitation to organization #{org.name} has been sent to #{params[:email]}.\n" \
                    "Their invite code is:\n  #{invitation_code}"
          status 200
          present membership, with: Webhookdb::API::OrganizationMembershipEntity, message:
        end
      end

      desc "Allows organization admin to remove customer from an organization"
      params do
        requires :email, type: String, allow_blank: false, coerce_with: NormalizedEmail,
                         prompt: "Enter the email of the member you are removing permissions from:"
        optional :guard_confirm
      end
      post :remove_member do
        customer = current_customer
        org = lookup_org!
        ensure_admin!
        email = params[:email]
        check_self_role_modification!(params[:email])
        customer.db.transaction do
          to_delete = org.memberships_dataset.where(customer: Webhookdb::Customer[email:])
          merror!(400, "That user is not a member of #{org.name}.") if to_delete.empty?
          to_delete.delete
          roll_back_if_no_admins!(org)
          status 200
          present({}, with: Webhookdb::AdminAPI::BaseEntity,
                      message: "#{email} is no longer a part of #{org.name}.",)
        end
      end

      desc "Updates the field on an org."
      params do
        requires :field, type: String
      end
      post :update do
        customer = current_customer
        org = lookup_org!
        ensure_admin!
        field_name = params[:field].split("=")[0]
        value = params[:field].split("=")[1]
        unless org.cli_editable_fields.include?(field_name)
          merror!(403, "That field is not editable from the command line")
        end
        customer.db.transaction do
          org.send("#{field_name}=", value)
          org.save_changes
          status 200
          present org, with: Webhookdb::API::OrganizationEntity,
                       message: "You have successfully updated the organization #{org.name}."
        end
      end

      desc "Allows organization admin to change customer's role in an organization"
      params do
        requires :emails, type: Array[String], coerce_with: CommaSepArray,
                          prompt: "Enter the emails to modify the roles of as a comma-separated list:"
        requires :role_name, type: String, values: Webhookdb::OrganizationMembership::VALID_ROLE_NAMES,
                             prompt: "Enter the name of the role to assign " \
                                     "(#{Webhookdb::OrganizationMembership::VALID_ROLE_NAMES.join(', ')}): "
        optional :guard_confirm
      end
      post :change_roles do
        customer = current_customer
        org = lookup_org!
        ensure_admin!
        params[:emails].each { |e| check_self_role_modification!(e) }
        customer.db.transaction do
          new_role = Webhookdb::Role.find_or_create_or_find(name: params[:role_name])
          memberships = org.memberships_dataset.where(customer: Webhookdb::Customer.where(email: params[:emails]))
          merror!(400, "Those emails do not belong to members of #{org.name}.") if memberships.empty?
          memberships.update(membership_role_id: new_role.id)
          roll_back_if_no_admins!(org)
          message = "Success! These users have now been assigned the role of #{new_role.name} in #{org.name}."
          status 200
          present_collection memberships, with: Webhookdb::API::OrganizationMembershipEntity, message:
        end
      end

      desc "Allow organization admin to change the name of the organization"
      params do
        optional :name, type: String, prompt: "Enter the new organization name:"
      end
      post :rename do
        customer = current_customer
        org = lookup_org!
        ensure_admin!
        customer.db.transaction do
          prev_name = org.name
          org.name = params[:name]
          org.save_changes
          status 200
          present org, with: Webhookdb::API::OrganizationEntity,
                       message: "The organization '#{org.key}' has been renamed from '#{prev_name}' to '#{org.name}'."
        end
      end

      desc "Request closure of an organization"
      post :close do
        org = lookup_org!
        ensure_admin!
        Sentry.capture_message("Org #{org.key} requested removal")
        step = Webhookdb::Services::StateMachineStep.new.completed
        step.output = "Thanks! We've received the request to close your #{org.name} organization. " \
                      "We'll be in touch within 2 business days confirming removal."
        status 200
        present step, with: Webhookdb::API::StateMachineEntity
      end
    end

    desc "Creates a new organization and adds current customer as a member."
    params do
      requires :name, type: String, allow_blank: false, prompt: "Enter the name of the organization:"
    end
    post :create do
      customer = current_customer
      customer.db.transaction do
        new_org = Webhookdb::Organization.create_if_unique(name: params[:name])
        merror!(400, "An organization with that name already exists.") if new_org.nil?
        new_org.billing_email = customer.email
        new_org.save_changes
        new_org.add_membership(customer:, membership_role: Webhookdb::Role.admin_role, verified: true)
        message = "Your organization identifier is: #{new_org.key}\nIt is now active.\n" \
                  "Use `webhookdb org invite` to invite members to #{new_org.name}."
        status 200
        present new_org, with: Webhookdb::API::OrganizationEntity, message:
      end
    end

    desc "Allows user to verify membership in an organization with an invitation code."
    params do
      requires :invitation_code, type: String, allow_blank: false, prompt: "Enter the invitation code:"
    end
    post :join do
      customer = current_customer
      customer.db.transaction do
        membership = customer.memberships_dataset[invitation_code: params[:invitation_code]]
        merror!(400, "Looks like that invite code is invalid. Please try again.") if membership.nil?
        membership.verified = true
        membership.save_changes
        message = "Congratulations! You are now a member of #{membership.organization_name}."
        status 200
        present membership, with: Webhookdb::API::OrganizationMembershipEntity, message:
      end
    end
  end
end
