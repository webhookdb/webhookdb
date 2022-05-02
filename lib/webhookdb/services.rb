# frozen_string_literal: true

require "webhookdb/typed_struct"

class Webhookdb::Services
  extend Webhookdb::MethodUtilities

  class InvalidService < RuntimeError; end

  class CredentialsMissing < RuntimeError; end

  # In the Descriptor struct, the value for :feature_roles is used in
  # our feature flagging functionality. It should default to [],
  # but other possible values to be included in the array are:
  #    -'internal' e.g. our fake integration
  #    -'unreleased' for works in progress
  #    -'beta' if we don't want most people to have access
  class Descriptor < Webhookdb::TypedStruct
    # @!attribute name
    #   @return [String]
    # @!attribute ctor
    #   @return [Proc]
    # @!attribute feature_roles
    #   @return [Array<String>]
    # @!attribute resource_name_singular
    #   @return [String]
    # @!attribute resource_name_plural
    #   @return [String]
    # @!attribute dependency_descriptor
    #   @return [Webhookdb::Services::Descriptor]
    attr_reader :name,
                :ctor,
                :resource_name_singular,
                :resource_name_plural,
                :feature_roles,
                :dependency_descriptor

    def initialize(
      name:,
      ctor:,
      resource_name_singular:,
      feature_roles:,
      resource_name_plural: nil,
      dependency_descriptor: nil
    )
      super(name:, resource_name_singular:, feature_roles:, dependency_descriptor:)
      @ctor = ctor.is_a?(Class) ? ctor.method(:new) : ctor
      @resource_name_plural = resource_name_plural || "#{self.resource_name_singular}s"
    end

    def inspect
      return "#{self.class.name}(name: #{self.name})"
    end

    def ==(other)
      return self.class == other.class &&
          self.name == other.name &&
          self.resource_name_singular == other.resource_name_singular
    end
  end

  class << self
    # @return [Hash{String => Webhookdb::Services::Descriptor}]
    def registered
      return @registered ||= {}
    end

    def register(cls)
      desc = cls.descriptor
      raise TypeError, "descriptor must be a Descriptor, got #{desc.class.name}" unless desc.is_a?(Descriptor)
      self.registered[desc.name] = desc
    end

    # Return a new service instance for the given integration.
    #
    # @param service_integration [Webhookdb::ServiceIntegration]
    # @return [Webhookdb::Services::Base]
    def service_instance(service_integration)
      name = service_integration.service_name
      descr = self.registered_service!(name)
      return descr.ctor.call(service_integration)
    end

    # @return [Webhookdb::Services::Descriptor]
    def registered_service(name)
      return @registered[name]
    end

    # @return [Webhookdb::Services::Descriptor]
    def registered_service!(name)
      r = self.registered_service(name)
      return r if r
      raise InvalidService, name
    end
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
require "webhookdb/services/plaid_item_v1"
require "webhookdb/services/plaid_transaction_v1"
require "webhookdb/services/shopify_customer_v1"
require "webhookdb/services/shopify_order_v1"
require "webhookdb/services/stripe_charge_v1"
require "webhookdb/services/stripe_coupon_v1"
require "webhookdb/services/stripe_customer_v1"
require "webhookdb/services/stripe_dispute_v1"
require "webhookdb/services/stripe_payout_v1"
require "webhookdb/services/stripe_price_v1"
require "webhookdb/services/stripe_product_v1"
require "webhookdb/services/stripe_refund_v1"
require "webhookdb/services/stripe_subscription_v1"
require "webhookdb/services/stripe_subscription_item_v1"
require "webhookdb/services/stripe_invoice_v1"
require "webhookdb/services/stripe_invoice_item_v1"
require "webhookdb/services/transistor_episode_v1"
require "webhookdb/services/transistor_show_v1"
require "webhookdb/services/twilio_sms_v1"
Webhookdb::Services.register(Webhookdb::Services::ConvertkitBroadcastV1)
Webhookdb::Services.register(Webhookdb::Services::ConvertkitSubscriberV1)
Webhookdb::Services.register(Webhookdb::Services::ConvertkitTagV1)
Webhookdb::Services.register(Webhookdb::Services::Fake)
Webhookdb::Services.register(Webhookdb::Services::FakeDependent)
Webhookdb::Services.register(Webhookdb::Services::FakeWithEnrichments)
Webhookdb::Services.register(Webhookdb::Services::IncreaseACHTransferV1)
Webhookdb::Services.register(Webhookdb::Services::IncreaseTransactionV1)
Webhookdb::Services.register(Webhookdb::Services::PlaidItemV1)
Webhookdb::Services.register(Webhookdb::Services::PlaidTransactionV1)
Webhookdb::Services.register(Webhookdb::Services::ShopifyCustomerV1)
Webhookdb::Services.register(Webhookdb::Services::ShopifyOrderV1)
Webhookdb::Services.register(Webhookdb::Services::StripeChargeV1)
Webhookdb::Services.register(Webhookdb::Services::StripeCouponV1)
Webhookdb::Services.register(Webhookdb::Services::StripeCustomerV1)
Webhookdb::Services.register(Webhookdb::Services::StripeDisputeV1)
Webhookdb::Services.register(Webhookdb::Services::StripePayoutV1)
Webhookdb::Services.register(Webhookdb::Services::StripePriceV1)
Webhookdb::Services.register(Webhookdb::Services::StripeProductV1)
Webhookdb::Services.register(Webhookdb::Services::StripeRefundV1)
Webhookdb::Services.register(Webhookdb::Services::StripeSubscriptionV1)
Webhookdb::Services.register(Webhookdb::Services::StripeSubscriptionItemV1)
Webhookdb::Services.register(Webhookdb::Services::StripeInvoiceV1)
Webhookdb::Services.register(Webhookdb::Services::StripeInvoiceItemV1)
Webhookdb::Services.register(Webhookdb::Services::TransistorEpisodeV1)
Webhookdb::Services.register(Webhookdb::Services::TransistorShowV1)
Webhookdb::Services.register(Webhookdb::Services::TwilioSmsV1)
