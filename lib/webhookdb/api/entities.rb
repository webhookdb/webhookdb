# frozen_string_literal: true

require "grape_entity"

require "webhookdb/service/entities"
require "webhookdb/api" unless defined? Webhookdb::API

module Webhookdb::API
  MoneyEntity = Webhookdb::Service::Entities::Money
  TimeRangeEntity = Webhookdb::Service::Entities::TimeRange

  class BaseEntity < Webhookdb::Service::Entities::Base
    expose :message do |_instance, options|
      options[:message] || ""
    end
  end

  class OrganizationEntity < BaseEntity
    expose :id
    expose :name
    expose :key
  end

  class OrganizationMembershipEntity < BaseEntity
    expose :customer_email, as: :email
    expose :organization, with: OrganizationEntity
    expose :organization_name, &self.delegate_to(:organization, :name)
    expose :organization_key, &self.delegate_to(:organization, :key)
    expose :status

    def self.display_headers
      return [
        [:email, "Email"],
        [:organization_name, "Organization Name"],
        [:organization_key, "Organization Key"],
        [:status, "Role"],
      ]
    end
  end

  class CurrentCustomerEntity < BaseEntity
    expose :email
    expose :name
    expose :default_organization, with: OrganizationEntity
    expose :default_organization_formatted,
           &self.delegate_to(:default_organization, :display_string, safe_with_default: "")
    expose :verified_memberships, with: OrganizationMembershipEntity
    expose :verified_memberships_formatted do |instance|
      lines = instance.verified_memberships.map { |m| "#{m.organization.display_string}: #{m.status}" }
      lines.join("\n")
    end
    expose :invited_memberships, as: :invitations, with: OrganizationMembershipEntity
    expose :invitations_formatted do |instance|
      lines = instance.invited_memberships.map { |m| "#{m.organization.display_string}: #{m.invitation_code}" }
      lines.join("\n")
    end
    expose :display_headers do |_|
      [
        [:email, "Email"],
        [:default_organization_formatted, "Default Org"],
        [:verified_memberships_formatted, "Memberships"],
        [:invitations_formatted, "Invitations"],
      ]
    end
  end

  class ServiceIntegrationEntity < BaseEntity
    expose :opaque_id
    expose :service_name
    expose :table_name

    def self.display_headers
      return [[:service_name, "Name"], [:table_name, "Table"], [:opaque_id, "Id"]]
    end
  end

  class ServiceEntity < BaseEntity
    expose :name

    def self.display_headers
      return [[:name, "Name"]]
    end
  end

  class StateMachineEntity < BaseEntity
    expose :needs_input
    expose :prompt
    expose :prompt_is_secret
    expose :post_to_url
    expose :post_params
    expose :post_params_value_key
    expose :complete
    expose :output
    expose :error_code
    expose :extras do |_, opts|
      opts[:extras] || {}
    end
  end

  class SubscriptionPlanEntity < BaseEntity
    expose :key
    expose :description
    expose :price, with: MoneyEntity
    expose :price_formatted, &self.delegate_to(:price, :format)

    def self.display_headers
      return [[:key, "Key"], [:description, "Description"], [:price_formatted, "Price"]]
    end
  end

  class WebhookSubscriptionEntity < BaseEntity
    expose :created_at
    expose :opaque_id
    expose :deliver_to_url
    expose :organization, with: OrganizationEntity
    expose :service_integration, with: ServiceIntegrationEntity
    expose :associated_type
    expose :associated_id
    expose :status

    def self.display_headers
      return [
        [:opaque_id, "Id"],
        [:deliver_to_url, "Url"],
        [:status, "Status"],
        [:associated_type, "Associated Type"],
        [:associated_id, "Associated Id"],
      ]
    end
  end

  class BaseSyncTargetEntity < BaseEntity
    expose :created_at
    expose :opaque_id
    expose :service_integration, with: ServiceIntegrationEntity
    expose :period_seconds
    expose :displaysafe_connection_url, as: :connection_url
    expose :table
    expose :schema
    expose :last_synced_at
    expose :associated_type
    expose :associated_id
    expose :associated_object_display
  end

  class DbSyncTargetEntity < BaseSyncTargetEntity
    expose :schema_and_table_string

    def self.display_headers
      return [
        [:opaque_id, "Id"],
        [:connection_url, "URL"],
        [:associated_object_display, "Associated"],
        [:schema_and_table_string, "Table"],
        [:last_synced_at, "Last Synced"],
        [:period_seconds, "Period"],
        [:page_size, "Page"],
      ]
    end
  end

  class HttpSyncTargetEntity < BaseSyncTargetEntity
    def self.display_headers
      return [
        [:opaque_id, "Id"],
        [:connection_url, "URL"],
        [:associated_object_display, "Associated"],
        [:last_synced_at, "Last Synced"],
        [:period_seconds, "Period"],
        [:page_size, "Page"],
      ]
    end
  end

  class DatabaseMigrationEntity < BaseEntity
    expose :created_at
    expose :started_at
    expose :finished_at
    expose :displaysafe_source_url, as: :source_url
    expose :displaysafe_destination_url, as: :destination_url
    expose :status

    def self.display_headers
      return [
        [:created_at, "Created at"],
        [:started_at, "Started at"],
        [:finished_at, "Finished at"],
        [:source_url, "Source"],
        [:destination_url, "Destination"],
        [:status, "Status"],
      ]
    end
  end

  class BackfillJobEntity < BaseEntity
    expose :opaque_id, as: :id
    expose :status
    expose :started_at
    expose :fully_finished_at, as: :finished_at
    expose :service_integration, with: ServiceIntegrationEntity
  end
end
