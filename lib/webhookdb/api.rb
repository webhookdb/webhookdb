# frozen_string_literal: true

require "grape"

require "webhookdb"
require "webhookdb/service"

# API is the namespace module for API resources.
module Webhookdb::API
  require "webhookdb/api/entities"

  class V1 < Webhookdb::Service
    def self.inherited(subclass)
      super
      subclass.instance_eval do
        version "v1", using: :path
        format :json

        require "webhookdb/service/helpers"
        helpers Webhookdb::Service::Helpers

        helpers do
          def verified_customer!
            c = current_customer
            forbidden! unless c.phone_verified?
            return c
          end

          def lookup_org!
            customer = current_customer
            org = Webhookdb::Organization.lookup_by_identifier(params[:identifier])
            merror!(403, "There is no organization with that identifier.") if org.nil?
            membership = customer.memberships_dataset[organization: org, verified: true]
            merror!(403, "You don't have permissions with that organization.") if membership.nil?
            return membership.organization
          end

          def ensure_admin!
            customer = current_customer
            org = lookup_org!
            admin_membership = org.memberships_dataset[customer: customer, membership_role: Webhookdb::Role.admin_role]
            # rubocop:disable Style/GuardClause
            if admin_membership.nil?
              merror!(400,
                      "Permission denied: You don't have admin privileges with #{org.name}.",)
            end
            # rubocop:enable Style/GuardClause
          end
        end

        before do
          Raven.tags_context(application: "public-api")
        end
      end
    end
  end
end
