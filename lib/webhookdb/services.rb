# frozen_string_literal: true

class Webhookdb::Services
  extend Webhookdb::MethodUtilities

  class InvalidService < RuntimeError; end

  class CredentialsMissing < RuntimeError; end

  singleton_attr_reader :registered
  @registered = {}

  # In the Descriptor struct, the value for :feature_roles is used in
  # our feature flagging functionality. It should default to [],
  # but other possible values to be included in the array are:
  #    -'internal' e.g. our fake integration
  #    -'unreleased' for works in progress
  #    -'beta' if we don't want most people to have access
  Descriptor = Struct.new(
    :name,
    :ctor,
    :feature_roles,
    keyword_init: true,
  )

  def self.register(cls)
    desc = cls.descriptor
    self.registered[desc[:name]] = desc
  end

  # Return a new service instance for the given integration.
  #
  # @param service_integration [Webhookdb::ServiceIntegration]
  # @return [Webhookdb::Services::Base]
  def self.service_instance(service_integration)
    name = service_integration.service_name
    cls = self.registered_service_type!(name)
    return cls.call(service_integration)
  end

  def self.registered_service_type(name)
    return @registered[name]
  end

  def self.registered_service_type!(name)
    r = self.registered_service_type(name)
    return r[:ctor] if r
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
require "webhookdb/services/stripe_refund_v1"
require "webhookdb/services/transistor_episode_v1"
require "webhookdb/services/transistor_show_v1"
require "webhookdb/services/twilio_sms_v1"
Webhookdb::Services.register(Webhookdb::Services::ConvertkitBroadcastV1)
Webhookdb::Services.register(Webhookdb::Services::ConvertkitSubscriberV1)
Webhookdb::Services.register(Webhookdb::Services::ConvertkitTagV1)
Webhookdb::Services.register(Webhookdb::Services::Fake)
Webhookdb::Services.register(Webhookdb::Services::FakeWithEnrichments)
Webhookdb::Services.register(Webhookdb::Services::IncreaseACHTransferV1)
Webhookdb::Services.register(Webhookdb::Services::IncreaseTransactionV1)
Webhookdb::Services.register(Webhookdb::Services::ShopifyCustomerV1)
Webhookdb::Services.register(Webhookdb::Services::ShopifyOrderV1)
Webhookdb::Services.register(Webhookdb::Services::StripeChargeV1)
Webhookdb::Services.register(Webhookdb::Services::StripeCustomerV1)
Webhookdb::Services.register(Webhookdb::Services::StripeRefundV1)
Webhookdb::Services.register(Webhookdb::Services::TransistorEpisodeV1)
Webhookdb::Services.register(Webhookdb::Services::TransistorShowV1)
Webhookdb::Services.register(Webhookdb::Services::TwilioSmsV1)
