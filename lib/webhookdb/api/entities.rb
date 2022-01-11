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
    expose :complete
    expose :output
    expose :error_code
  end

  class WebhookSubscriptionEntity < BaseEntity
    expose :opaque_id
    expose :deliver_to_url
    expose :organization, with: OrganizationEntity
    expose :service_integration, with: ServiceIntegrationEntity
  end
end
