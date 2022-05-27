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
        require "webhookdb/api/helpers"
        helpers Webhookdb::API::Helpers

        helpers do
          def verified_customer!
            c = current_customer
            forbidden! unless c.phone_verified?
            return c
          end

          def lookup_org!(identifier=params[:org_identifier])
            customer = current_customer
            org = Webhookdb::Organization.lookup_by_identifier(identifier)
            merror!(403, "There is no organization with that identifier.") if org.nil?
            membership = customer.verified_memberships_dataset[organization: org]
            merror!(403, "You don't have permissions with that organization.") if membership.nil?
            return membership.organization
          end

          def lookup_service_integration!(org, opaque_id)
            sint = org.service_integrations_dataset[opaque_id:]
            merror!(403, "There is no service integration with that identifier.") if sint.nil? || sint.soft_deleted?
            return sint
          end

          def ensure_admin!
            customer = current_customer
            org = lookup_org!
            admin_membership = org.verified_memberships_dataset[customer:, membership_role: Webhookdb::Role.admin_role]
            # rubocop:disable Style/GuardClause
            if admin_membership.nil?
              merror!(400,
                      "Permission denied: You don't have admin privileges with #{org.name}.",)
            end
            # rubocop:enable Style/GuardClause
          end
        end

        before do
          Sentry.configure_scope do |scope|
            scope.set_tags(application: "public-api")
          end
        end
      end
    end
  end
end
