# frozen_string_literal: true

require "stripe"
require "webhookdb/services/stripe_v1_mixin"

class Webhookdb::Services::StripeChargeV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::StripeV1Mixin

  # @return [Webhookdb::Services::Descriptor]
  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "stripe_charge_v1",
      ctor: ->(sint) { Webhookdb::Services::StripeChargeV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "Stripe Charge",
    )
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:stripe_id, TEXT, data_key: "id")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:amount, INTEGER, index: true),
      Webhookdb::Services::Column.new(:balance_transaction, TEXT, index: true),
      Webhookdb::Services::Column.new(
        :billing_email, TEXT,
        index: true,
        data_key: ["billing_details", "email"],
        optional: true,
      ),
      Webhookdb::Services::Column.new(:created, TIMESTAMP, index: true, converter: :tsat),
      Webhookdb::Services::Column.new(:customer, TEXT, index: true, optional: true),
      Webhookdb::Services::Column.new(:invoice, TEXT, index: true, optional: true),
      Webhookdb::Services::Column.new(
        :payment_type, TEXT,
        data_key: ["payment_method_details", "type"],
        optional: true,
      ),
      Webhookdb::Services::Column.new(:receipt_email, TEXT, index: true, optional: true),
      Webhookdb::Services::Column.new(:status, TEXT, index: true),
      Webhookdb::Services::Column.new(
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
