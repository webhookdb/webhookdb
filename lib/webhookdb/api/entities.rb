# frozen_string_literal: true

require "grape_entity"

require "webhookdb/service/entities"
require "webhookdb/api" unless defined? Webhookdb::API

module Webhookdb::API
  CurrentCustomerEntity = Webhookdb::Service::Entities::CurrentCustomer
  MoneyEntity = Webhookdb::Service::Entities::Money
  TimeRangeEntity = Webhookdb::Service::Entities::TimeRange

  class BaseEntity < Webhookdb::Service::Entities::Base; end

  class CustomerSettingsEntity < BaseEntity
    expose :id
    expose :name
  end

  class OrganizationMembershipEntity < BaseEntity
    expose :id
    expose :customer_email, as: :email
    expose :status
  end

  class OrganizationEntity < BaseEntity
    expose :id
    expose :name
  end

  class ServiceIntegrationEntity < BaseEntity
    expose :id
    expose :opaque_id
    expose :service_name
    expose :table_name
  end
end
