# frozen_string_literal: true

require "grape"

require "webhookdb/api"
require "webhookdb/admin_api"

class Webhookdb::API::Organizations < Webhookdb::API::V1
  resource :organizations do
    desc "Return all organizations the customer is part of."
    get do
      customer = current_customer
      orgs = Webhookdb::Organization.where(memberships: customer.memberships_dataset).all
      message = orgs.empty? ? "You aren't affiliated with any organizations yet." : ""
      present_collection orgs, with: Webhookdb::API::OrganizationEntity, message: message
    end

    # GET

    route_param :identifier, type: String do
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

      resource :service_integrations do
        helpers do
          def lookup_sint!
            sint = Webhookdb::ServiceIntegration[opaque_id: params[:opaque_id]]
            merror!(400, "No integration with that id") if sint.nil? || sint.soft_deleted?
            return sint
          end
        end

        desc "Return all integrations associated with the organization."
        get do
          integrations = lookup_org!.service_integrations
          message = integrations.empty? ? "Organization doesn't have any integrations yet." : ""
          present_collection integrations, with: Webhookdb::API::ServiceIntegrationEntity, message: message
        end

        resource :create do
          helpers do
            def create_integration(org, name)
              if Webhookdb::Services.registered_service_type(name).nil?
                available_services = Webhookdb::Services.registered.keys.join("\n\t")
                step = Webhookdb::Services::StateMachineStep.new
                step.needs_input = false
                step.output =
                  %(
WebhookDB doesn't support a service called '#{name}.' These are all the services
currently supported by WebhookDB:

\t#{available_services}

You can run `webhookdb services list` at any time to see our list of available services.
                    )
                step.complete = true
                return step
              end
              sint = Webhookdb::ServiceIntegration[organization: org, service_name: name]
              if sint.nil?
                sint = Webhookdb::ServiceIntegration.create(
                  organization: org,
                  table_name: (name + "_#{SecureRandom.hex(2)}"),
                  service_name: name,
                  opaque_id: SecureRandom.hex(6),
                )
              end
              return sint.calculate_create_state_machine
            end
          end
          desc "Create service integration on a given organization"
          params do
            requires :service_name, type: String, allow_blank: false
          end
          post do
            customer = current_customer
            org = lookup_org!
            merror!(402, "You have reached the maximum number of free integrations") unless org.can_add_new_integration?
            ensure_admin!
            customer.db.transaction do
              state_machine = create_integration(org, params[:service_name])
              status 200
              present state_machine, with: Webhookdb::API::StateMachineEntity
            end
          end
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
            Webhookdb::OrganizationMembership.where(id: membership.id).update(invitation_code: invitation_code)

            Webhookdb.publish("webhookdb.organizationmembership.invite", membership.id)
            message = "An invitation has been sent to #{params[:email]}. Their invite code is: \n #{invitation_code}"
            status 200
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
            status 200
            present({}, with: Webhookdb::AdminAPI::BaseEntity,
                        message: "#{params[:email]} is no longer a part of the Lithic Technology organization.",)
          end
        end
      end

      resource :update do
        desc "begins process of updating a field on an org"
        params do
          requires :field, type: String
        end
        post do
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
      end

      resource :change_roles do
        desc "Allows organization admin to change customer's role in an organization"
        params do
          requires :emails, type: Array[String], coerce_with: ->(val) { val.split(",") }
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
            status 200
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
          new_org.billing_email = customer.email
          new_org.save_changes
          new_org.add_membership(customer: customer, role: Webhookdb::OrganizationRole.admin_role, verified: true)
          message = "Your organization identifier is: #{new_org.key} \n Use `webhookdb org invite <email>` " \
            "to invite members to #{new_org.name}."
          status 200
          present new_org, with: Webhookdb::API::OrganizationEntity, message: message
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
          membership.save_changes
          message = "Congratulations! You are now a member of #{membership.organization_name}."
          status 200
          present membership, with: Webhookdb::API::OrganizationMembershipEntity, message: message
        end
      end
    end
  end
end
