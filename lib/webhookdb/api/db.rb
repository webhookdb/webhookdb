# frozen_string_literal: true

require "grape"

require "webhookdb/api"
require "webhookdb/services"

class Webhookdb::API::Db < Webhookdb::API::V1
  resource :db do
    helpers do
      def lookup_org!
        customer = current_customer
        organization = Webhookdb::Organization.where(key: params[:organization_key])
        merror!(400, "There is no organization with the key #{params[:organization_key]}") if organization.nil?
        membership = customer.memberships_dataset[organization: organization, verified: true]
        merror!(403, "You don't have permissions with that organization.") if membership.nil?
        return membership.organization
      end
    end

    route_param :organization_key, type: String do
      desc "Returns a list of all tables in the organization's db."
      get do
        _customer = current_customer
        org = lookup_org!
        r = {tables: org.db.tables}
        present r
      end

      resource :sql do
        desc "Returns a list of all tables in the organization's db."
        params do
          requires :query, type: String, allow_blank: false
        end
        get do
          _customer = current_customer
          org = lookup_org!
          ds = org.db.fetch(params[:query])
          rows = []
          ds.each do |row|
            rows << row.values
            break if rows.length >= 1000
          end
          # We probably want to add in the count, and whether things were truncated
          # For the future
          r = {rows: rows, columns: ds.columns}
          present r
        end
      end
    end
  end
end
