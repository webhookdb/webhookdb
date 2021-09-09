# frozen_string_literal: true

class Webhookdb::Services
  extend Webhookdb::MethodUtilities

  class InvalidService < RuntimeError; end

  class CredentialsMissing < RuntimeError; end

  singleton_attr_reader :registered
  @registered = {}

  def self.register(name, factory)
    self.registered[name] = factory
  end

  # Return a new service instance for the given integration.
  #
  # @param service_integration [Webhookdb::ServiceIntegration]
  # @return [Webhookdb::Services::Base]
  def self.service_instance(service_integration)
    name = service_integration.service_name
    (cls = @registered[name]) or raise(InvalidService, name)
    return cls[service_integration]
  end
end

require "webhookdb/services/column"
require "webhookdb/services/base"
require "webhookdb/services/fake"
require "webhookdb/services/increase_ach_transfer_v1"
require "webhookdb/services/increase_transaction_v1"
require "webhookdb/services/shopify_customer_v1"
require "webhookdb/services/shopify_order_v1"
require "webhookdb/services/stripe_charge_v1"
require "webhookdb/services/stripe_customer_v1"
require "webhookdb/services/twilio_sms_v1"
Webhookdb::Services.register("fake_v1", ->(sint) { Webhookdb::Services::Fake.new(sint) })
Webhookdb::Services.register("increase_ach_transfer_v1", lambda { |sint|
  Webhookdb::Services::IncreaseACHTransferV1.new(sint)
},)
Webhookdb::Services.register("increase_transaction_v1", lambda { |sint|
  Webhookdb::Services::IncreaseTransactionV1.new(sint)
},)
Webhookdb::Services.register("shopify_customer_v1", ->(sint) { Webhookdb::Services::ShopifyCustomerV1.new(sint) })
Webhookdb::Services.register("shopify_order_v1", ->(sint) { Webhookdb::Services::ShopifyOrderV1.new(sint) })
Webhookdb::Services.register("stripe_charge_v1", ->(sint) { Webhookdb::Services::StripeChargeV1.new(sint) })
Webhookdb::Services.register("stripe_customer_v1", ->(sint) { Webhookdb::Services::StripeCustomerV1.new(sint) })
Webhookdb::Services.register("twilio_sms_v1", ->(sint) { Webhookdb::Services::TwilioSmsV1.new(sint) })
