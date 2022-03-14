# frozen_string_literal: true

require "grape_entity"

require "webhookdb/service/entities"
require "webhookdb/api" unless defined? Webhookdb::API

module Webhookdb::API
  MoneyEntity = Webhookdb::Service::Entities::Money
  TimeRangeEntity = Webhookdb::Service::Entities::TimeRange

  class BaseEntity < Webhookdb::Service::Entities::Base; end

  class CustomerSettingsEntity < BaseEntity
    expose :name
  end

  class OrganizationEntity < BaseEntity
    expose :id
    expose :name
    expose :key
  end

  class OrganizationMembershipEntity < BaseEntity
    expose :customer_email, as: :email
    expose :organization, with: OrganizationEntity
    expose :status
  end

  class CurrentCustomerEntity < BaseEntity
    expose :email
    expose :name
    expose :memberships, with: OrganizationMembershipEntity
    expose :default_organization, with: OrganizationEntity
  end

  class ServiceIntegrationEntity < BaseEntity
    expose :opaque_id
    expose :service_name
    expose :table_name
  end

  class ServiceEntity < BaseEntity
    expose :name
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

  # We do NOT want the message here, so use Grape directly
  class SubscriptionPlanEntity < Grape::Entity
    expose :key
    expose :description
    expose :price, with: MoneyEntity
  end

  class WebhookSubscriptionEntity < BaseEntity
    expose :created_at
    expose :opaque_id
    expose :deliver_to_url
    expose :organization, with: OrganizationEntity
    expose :service_integration, with: ServiceIntegrationEntity
    expose :associated_type
    expose :associated_id
  end
end
