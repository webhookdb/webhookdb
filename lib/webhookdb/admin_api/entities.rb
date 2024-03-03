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

  class Related < Grape::Entity
    expose :id
  end

  class BackfillJob < Base
    expose :service_integration, with: Related
    expose :organization, with: Related, &self.delegate_to(:service_integration, :organization)
    expose :started_at
    expose :finished_at
    expose :opaque_id
    expose :parent_job, with: Related
    expose :created_by, with: Related
    expose :incremental
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
    expose :customer, with: Related
  end

  class LoggedWebhook < Base
    expose :inserted_at
    expose :truncated_at
    expose :request_body
    expose(:request_headers) { |inst| inst.request_headers.to_a }
    expose :response_status
    expose :service_integration_opaque_id
    expose :service_integration, with: Related
    expose :organization, with: Related
    expose :request_method
    expose :request_path
  end

  class MessageBody < Base
    expose :content
    expose :mediatype
    expose :delivery, with: Related
  end

  class MessageDelivery < Base
    expose :extra_fields
    expose :recipient, with: Related
    expose :sent_at
    expose :template
    expose :to
    expose :transport_type
    expose :transport_service
    expose :transport_message_id
  end

  class Organization < Base
    expose :name
    expose :key
  end

  class OrganizationDatabaseMigration < Base
    expose :organization, with: Related
    expose :started_at
    expose :finished_at
    expose :started_by, with: Related
    expose :organization_schema
    expose :last_migrated_service_integration_id
    expose :last_migrated_service_integration, with: Related
    expose :last_migrated_timestamp
  end

  class OrganizationMembership < Base
    expose :organization, with: Related
    expose :customer, with: Related
    expose :membership_role, with: Related
    expose :verified
    expose :invitation_code
    expose :is_default
  end

  class Role < Base
    expose :name
  end

  class SavedQuery < Base
    expose :organization, with: Related
    expose :created_by, with: Related
    expose :opaque_id
    expose :description
    expose :sql
    expose :public
  end

  class SavedView < Base
    expose :organization, with: Related
    expose :created_by, with: Related
    expose :name
    expose :sql
  end

  class ServiceIntegration < Base
    expose :organization, with: Related
    expose :table_name
    expose :service_name
    expose :opaque_id
    expose :last_backfilled_at
    expose :depends_on, with: Related
    expose :skip_webhook_verification
  end

  class Subscription < Base
    expose :organization, with: Related
    expose :stripe_id
    expose :stripe_customer_id
    expose :stripe_json
  end

  class SyncTarget < Base
    expose :organization, with: Related
    expose :service_integration, with: Related
    expose :created_by, with: Related
    expose :opaque_id
    expose :period_seconds
    expose :schema
    expose :table
    expose :last_synced_at
    expose :last_applied_schema
    expose :page_size
  end

  class WebhookSubscription < Base
    expose :organization, with: Related
    expose :service_integration, with: Related
    expose :created_by, with: Related
    expose :opaque_id
    expose :deliver_to_url
    expose :deactivated_at
  end

  class WebhookSubscriptionDelivery < Base
    expose :attempt_timestamps
    expose :attempt_http_response_statuses
    expose :payload
    expose :webhook_subscription, with: Related
  end
end
