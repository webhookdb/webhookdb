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
    cls = self.registered_service_type!(name)
    return cls[service_integration]
  end

  def self.registered_service_type(name)
    return @registered[name]
  end

  def self.registered_service_type!(name)
    r = self.registered_service_type(name)
    return r if r
    raise InvalidService, name
  end
end

require "webhookdb/services/state_machine_step"
require "webhookdb/services/column"
require "webhookdb/services/base"
require "webhookdb/services/convertkit_broadcast_v1"
require "webhookdb/services/convertkit_subscriber_v1"
require "webhookdb/services/convertkit_tag_v1"
require "webhookdb/services/fake"
require "webhookdb/services/increase_ach_transfer_v1"
require "webhookdb/services/increase_transaction_v1"
require "webhookdb/services/shopify_customer_v1"
require "webhookdb/services/shopify_order_v1"
require "webhookdb/services/stripe_charge_v1"
require "webhookdb/services/stripe_customer_v1"
require "webhookdb/services/transistor_episode_v1"
require "webhookdb/services/transistor_show_v1"
require "webhookdb/services/twilio_sms_v1"
# rubocop:disable Layout/LineLength
Webhookdb::Services.register("convertkit_broadcast_v1", ->(sint) { Webhookdb::Services::ConvertkitBroadcastV1.new(sint) })
Webhookdb::Services.register("convertkit_subscriber_v1", ->(sint) { Webhookdb::Services::ConvertkitSubscriberV1.new(sint) })
Webhookdb::Services.register("convertkit_tag_v1", ->(sint) { Webhookdb::Services::ConvertkitTagV1.new(sint) })
Webhookdb::Services.register("fake_v1", ->(sint) { Webhookdb::Services::Fake.new(sint) })
Webhookdb::Services.register("fake_with_enrichments_v1", ->(sint) { Webhookdb::Services::FakeWithEnrichments.new(sint) })
Webhookdb::Services.register("increase_ach_transfer_v1", ->(sint) { Webhookdb::Services::IncreaseACHTransferV1.new(sint) })
Webhookdb::Services.register("increase_transaction_v1", ->(sint) { Webhookdb::Services::IncreaseTransactionV1.new(sint) })
# rubocop:enable Layout/LineLength
Webhookdb::Services.register("shopify_customer_v1", ->(sint) { Webhookdb::Services::ShopifyCustomerV1.new(sint) })
Webhookdb::Services.register("shopify_order_v1", ->(sint) { Webhookdb::Services::ShopifyOrderV1.new(sint) })
Webhookdb::Services.register("stripe_charge_v1", ->(sint) { Webhookdb::Services::StripeChargeV1.new(sint) })
Webhookdb::Services.register("stripe_customer_v1", ->(sint) { Webhookdb::Services::StripeCustomerV1.new(sint) })
Webhookdb::Services.register("transistor_episode_v1", ->(sint) { Webhookdb::Services::TransistorEpisodeV1.new(sint) })
Webhookdb::Services.register("transistor_show_v1", ->(sint) { Webhookdb::Services::TransistorShowV1.new(sint) })
Webhookdb::Services.register("twilio_sms_v1", ->(sint) { Webhookdb::Services::TwilioSmsV1.new(sint) })
