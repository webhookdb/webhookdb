# frozen_string_literal: true

require "grape_entity"

require "webhookdb/service/entities"
require "webhookdb/admin_api" unless defined? Webhookdb::AdminAPI

module Webhookdb::AdminAPI::Entities
  CurrentCustomer = Webhookdb::Service::Entities::CurrentCustomer
  Money = Webhookdb::Service::Entities::Money
  TimeRange = Webhookdb::Service::Entities::TimeRange

  class Base < Webhookdb::Service::Entities::Base
    expose :id, if: ->(o) { o.respond_to?(:id) }
    expose :created_at, if: ->(o) { o.respond_to?(:created_at) }
    expose :updated_at, if: ->(o) { o.respond_to?(:updated_at) }
    expose :soft_deleted_at, if: ->(o) { o.respond_to?(:soft_deleted_at) }
    expose :admin_link, if: ->(o, _) { o.respond_to?(:admin_link) }
  end

  class Role < Base
    expose :name
  end

  class Customer < Base
    expose :email
    expose :name
    expose :note
  end

  class CustomerResetCode < Base
    expose :transport
    expose :token
    expose :used
    expose :expire_at
    expose :customer_id
  end

  class Organization < Base
    expose :name
    expose :key
  end

  class OrganizationMembership < Base
    expose :organization_id
    expose :customer_id
    expose :membership_role_id
    expose :verified
    expose :invitation_code
    expose :is_default
  end

  class MessageDelivery < Base
    expose :template
    expose :transport_type
    expose :transport_service
    expose :transport_message_id
    expose :sent_at
    expose :to
  end

  class MessageBody < Base
    expose :content
    expose :mediatype
    expose :delivery_id
  end
end
