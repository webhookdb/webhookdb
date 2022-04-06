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
    )
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:stripe_id, "text")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:amount, "integer", index: true),
      Webhookdb::Services::Column.new(:balance_transaction, "text", index: true),
      Webhookdb::Services::Column.new(:billing_email, "text", index: true),
      Webhookdb::Services::Column.new(:created, "timestamptz", index: true),
      Webhookdb::Services::Column.new(:customer, "text", index: true),
      Webhookdb::Services::Column.new(:invoice, "text", index: true),
      Webhookdb::Services::Column.new(:payment_type, "text"),
      Webhookdb::Services::Column.new(:receipt_email, "text", index: true),
      Webhookdb::Services::Column.new(:status, "text", index: true),
      Webhookdb::Services::Column.new(:updated, "timestamptz", index: true),
    ]
  end

  def _update_where_expr
    return Sequel[self.table_sym][:updated] < Sequel[:excluded][:updated]
  end

  def _prepare_for_insert(body, **_kwargs)
    obj_of_interest, updated = self._extract_obj_and_updated(body)
    return {
      data: obj_of_interest.to_json,
      amount: obj_of_interest.fetch("amount"),
      balance_transaction: obj_of_interest.fetch("balance_transaction"),
      billing_email: obj_of_interest.dig("billing_details", "email"),
      created: self.tsat(obj_of_interest.fetch("created")),
      customer: obj_of_interest["customer"],
      invoice: obj_of_interest["invoice"],
      payment_type: obj_of_interest.dig("payment_method_details", "type"),
      receipt_email: obj_of_interest["receipt_email"],
      status: obj_of_interest.fetch("status"),
      updated: self.tsat(updated),
      stripe_id: obj_of_interest.fetch("id"),
    }
  end

  def _mixin_name_singular
    return "Stripe Charge"
  end

  def _mixin_name_plural
    return "Stripe Charges"
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
