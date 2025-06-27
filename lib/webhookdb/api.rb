# frozen_string_literal: true

require "grape"

require "webhookdb"
require "webhookdb/service"
require "webhookdb/service/helpers"

module Webhookdb::API
  class V1 < Webhookdb::Service
    def self.inherited(subclass)
      super
      subclass.instance_eval do
        version "v1", using: :path
        format :json

        helpers Webhookdb::Service::Helpers
        helpers Webhookdb::API::Helpers

        helpers do
          def verified_customer!
            c = current_customer
            forbidden! unless c.phone_verified?
            return c
          end

          # Lookup the organization.
          # @param identifier [String] Can be passed in, or is extracted from the route params
          #   (:org_identifier, or :org if :org_identiier is '-').
          # @param customer [Webhookdb::Customer] Authed customer. Will use current_customer if nil.
          # @param allow_connstr_auth [Boolean] True to use Webhookdb::API::ConnstrAuth.
          #   See module for more details.
          def lookup_org!(identifier=nil, customer: nil, allow_connstr_auth: false)
            identifier ||= params[:org_identifier]
            if identifier == "-"
              identifier = params[:org]
              merror!(400, "must supply 'org_identifier' or 'org' param", code: "missing_org") unless identifier
            end
            # Run this first to verify authentication before other lookups.
            customer ||= allow_connstr_auth ? current_customer? : current_customer
            # Can return multiple orgs, including ones the user cannot access
            orgs = Webhookdb::Organization.with_identifier(identifier).all
            merror!(403, "There is no organization with that identifier.") if orgs.empty?
            if customer
              # This is scoped to just orgs the user can access. We check if the identifier
              # matches multiple orgs, in which case it's ambiguous.
              memberships = customer.verified_memberships_dataset.where(organization: orgs).limit(2).all
              permission_error!("You don't have permissions with that organization.") if memberships.empty?
              merror!(500, "ambiguous", alert: true) if memberships.size > 1 # TODO: better message, tests
              org = memberships.first.organization
              set_request_tags(organization: org.key)
              return org
            end
            raise "something went wrong" unless allow_connstr_auth
            org = Webhookdb::API::ConnstrAuth.find_authed(orgs, request)
            unauthenticated! if org.nil?
            set_request_tags(organization: org.key)
            return org
          end

          def has_admin?(org=nil, customer: nil)
            customer ||= current_customer
            org ||= lookup_org!
            has_no_admin = org.verified_memberships_dataset.
              where(customer:, membership_role: Webhookdb::Role.admin_role).
              empty?
            return !has_no_admin
          end

          def ensure_admin!(org=nil, customer: nil)
            org ||= lookup_org!
            admin = has_admin?(org, customer:)
            # noinspection RubyNilAnalysis
            permission_error!("You don't have admin privileges with #{org.name}.") unless admin
          end
        end

        before do
          Sentry.configure_scope do |scope|
            scope.set_tags(application: "public-api")
          end
        end

        before_validation do
          # We want to strip control characters out of the string inputs
          # Found the control character regex here:
          #    https://www.appsloveworld.com/ruby/100/167/how-to-remove-control-characters-in-ruby
          #
          rgx = /\e\[[^\x40-\x7E]*[\x40-\x7E]/
          self.params.each do |k, v|
            params[k] = v.gsub(rgx, "") if v.is_a?(String)
          end
        end
      end
    end
  end
end

require "webhookdb/api/entities"
require "webhookdb/api/connstr_auth"
require "webhookdb/api/helpers"
