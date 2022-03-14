# frozen_string_literal: true

require "grape"

require "webhookdb/api"

class Webhookdb::API::Me < Webhookdb::API::V1
  resource :me do
    desc "Return the current customer"
    get do
      customer = current_customer
      present customer, with: Webhookdb::API::CurrentCustomerEntity, env:
    end

    resource :organization_memberships do
      desc "Return all organizations the customer is part of."
      params do
        optional :active_org_identifier
      end
      get do
        customer = current_customer
        active_org = Webhookdb::Organization.lookup_by_identifier(params[:active_org_identifier])
        memberships, invited = Webhookdb::OrganizationMembership.where(customer:).all.partition(&:verified)
        blocks = Webhookdb::Formatting.blocks
        unless memberships.empty?
          blocks.line("You are a member of the following organizations:")
          blocks.blank
          # the word "Status" here is referring to whether the org is "active" in the CLI. This designation
          # is added by the client
          rows = memberships.map do |m|
            cli_status = m.organization === active_org ? "active" : ""
            [m.organization.name, m.organization.key, m.status, cli_status]
          end
          blocks.table(["Name", "Key", "Role", "Status"], rows)
        end
        blocks.blank if memberships.present? && invited.present?
        unless invited.empty?
          blocks.line("You have been invited to the following organizations:")
          blocks.blank
          rows = invited.map do |m|
            [m.organization.name, m.organization.key, m.invitation_code]
          end
          blocks.table(["Name", "Key", "Join Code"], rows)
          blocks.blank
          blocks.line("To join an invited org, use: webhookdb org join <join code>.")
        end
        blocks.line("You aren't affiliated with any organizations yet.") if memberships.empty? && invited.empty?
        r = {blocks: blocks.as_json}
        present r
      end
    end
  end
end
