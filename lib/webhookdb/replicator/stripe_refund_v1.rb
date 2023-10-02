# frozen_string_literal: true

require "stripe"
require "webhookdb/replicator/stripe_v1_mixin"

class Webhookdb::Replicator::StripeRefundV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::StripeV1Mixin

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "stripe_refund_v1",
      ctor: ->(sint) { Webhookdb::Replicator::StripeRefundV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "Stripe Refund",
      supports_webhooks: true,
      supports_backfill: true,
    )
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:stripe_id, TEXT, data_key: "id")
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:amount, INTEGER, index: true),
      Webhookdb::Replicator::Column.new(:balance_transaction, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:charge, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:created, TIMESTAMP, index: true, converter: :tsat),
      Webhookdb::Replicator::Column.new(:payment_intent, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:receipt_number, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:source_transfer_reversal, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:status, TEXT),
      Webhookdb::Replicator::Column.new(:transfer_reversal, TEXT, index: true),
      Webhookdb::Replicator::Column.new(
        :updated,
        TIMESTAMP,
        index: true,
        data_key: "created",
        event_key: "created",
        converter: :tsat,
      ),
    ]
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:updated] < Sequel[:excluded][:updated]
  end

  def _mixin_backfill_url
    return "https://api.stripe.com/v1/refunds"
  end

  def _mixin_event_type_names
    return ["charge.refund.updated"]
  end

  def restricted_key_resource_name = "Charges"

  def _upsert_webhook(request, upsert: true)
    object_type = request.body.fetch("object")
    return super if object_type == "refund"

    # Because there is no actual "refunds" webhook, we have to pull a list of refunds
    # from the "charges" webhook. There is a somewhat infuriating nested pagination
    # mechanism here, where the refunds list in the charge takes this form:
    #
    #    "refunds": {
    #       "object": "list",
    #       "data": [],
    #       "has_more": false,
    #       "url": "/v1/charges/ch_1JG8U9FFYxHXGyKxPaNIdc0b/refunds"
    #    }
    #
    # and the `has_more` and `url` fields contain the information that is rquired to kick off
    # a paginated backfill. `has_more` is almost always going to be false, because it should be
    # rare that a charge has more than ten refunds, so we're just going to ignore this concern
    # for now and issue a DeveloperAlert if pagination is required.
    refunds_obj = request.body.dig("data", "object", "refunds")

    if refunds_obj.fetch("has_more") == true
      Webhookdb::DeveloperAlert.new(
        subsystem: "Stripe Refunds Webhook Error",
        emoji: ":hook:",
        fallback: "Full backfill required for integration #{self.service_integration.opaque_id}",
        fields: [],
      ).emit
    end

    refunds_obj.fetch("data").each do |b|
      new_request = request.dup
      new_request.body = b
      super(new_request, upsert:)
    end
  end
end
