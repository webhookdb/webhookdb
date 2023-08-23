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
end
