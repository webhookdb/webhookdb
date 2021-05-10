# frozen_string_literal: true

require "grape_entity"

require "webhookdb/service/entities"
require "webhookdb/admin_api" unless defined? Webhookdb::AdminAPI

module Webhookdb::AdminAPI
  CurrentCustomerEntity = Webhookdb::Service::Entities::CurrentCustomer
  MoneyEntity = Webhookdb::Service::Entities::Money
  TimeRangeEntity = Webhookdb::Service::Entities::TimeRange

  class BaseEntity < Webhookdb::Service::Entities::Base; end

  class RoleEntity < BaseEntity
    expose :id
    expose :name
  end

  class CustomerEntity < BaseEntity
    expose :id
    expose :created_at
    expose :email
    expose :name
    expose :name
    expose :note
  end

  class CustomerResetCodes < BaseEntity
    expose :id
    expose :created_at
    expose :transport
    expose :token
    expose :used
    expose :expire_at
  end

  class DetailedCustomerEntity < CustomerEntity
    expose :roles do |instance|
      instance.roles.map(&:name)
    end
    expose :reset_codes, with: CustomerResetCodes
  end

  class MessageBodyEntity < BaseEntity
    expose :id
    expose :content
    expose :mediatype
  end

  class MessageDeliveryEntity < BaseEntity
    expose :id
    expose :created_at
    expose :updated_at
    expose :soft_deleted_at
    expose :template
    expose :transport_type
    expose :transport_service
    expose :transport_message_id
    expose :sent_at
    expose :to
  end

  class MessageDeliveryWithBodiesEntity < MessageDeliveryEntity
    expose :bodies, with: MessageBodyEntity
  end
end
