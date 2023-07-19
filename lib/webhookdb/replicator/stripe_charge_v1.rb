# frozen_string_literal: true

require "stripe"
require "webhookdb/replicator/stripe_v1_mixin"

class Webhookdb::Replicator::StripeChargeV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::StripeV1Mixin

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "stripe_charge_v1",
      ctor: ->(sint) { Webhookdb::Replicator::StripeChargeV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "Stripe Charge",
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
      Webhookdb::Replicator::Column.new(
        :billing_email, TEXT,
        index: true,
        data_key: ["billing_details", "email"],
        optional: true,
      ),
      Webhookdb::Replicator::Column.new(:created, TIMESTAMP, index: true, converter: :tsat),
      Webhookdb::Replicator::Column.new(:customer, TEXT, index: true, optional: true),
      Webhookdb::Replicator::Column.new(:invoice, TEXT, index: true, optional: true),
      Webhookdb::Replicator::Column.new(
        :payment_type, TEXT,
        data_key: ["payment_method_details", "type"],
        optional: true,
      ),
      Webhookdb::Replicator::Column.new(:receipt_email, TEXT, index: true, optional: true),
      Webhookdb::Replicator::Column.new(:status, TEXT, index: true),
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
    return "https://api.stripe.com/v1/charges"
  end

  def _mixin_event_type_names
    return [
      "charge.captured",
      "charge.expired",
      "charge.failed",
      "charge.pending",
      "charge.refunded",
      "charge.succeeded",
      "charge.updated",
    ]
  end
end
