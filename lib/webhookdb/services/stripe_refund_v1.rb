# frozen_string_literal: true

require "stripe"
require "webhookdb/services/stripe_v1_mixin"

class Webhookdb::Services::StripeRefundV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::StripeV1Mixin

  # @return [Webhookdb::Services::Descriptor]
  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "stripe_refund_v1",
      ctor: ->(sint) { Webhookdb::Services::StripeRefundV1.new(sint) },
      feature_roles: ["beta"],
    )
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:stripe_id, "text")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:amount, "integer", index: true),
      Webhookdb::Services::Column.new(:balance_transaction, "text", index: true),
      Webhookdb::Services::Column.new(:charge, "text", index: true),
      Webhookdb::Services::Column.new(:created, "timestamptz", index: true),
      Webhookdb::Services::Column.new(:payment_intent, "text", index: true),
      Webhookdb::Services::Column.new(:receipt_number, "text", index: true),
      Webhookdb::Services::Column.new(:source_transfer_reversal, "text", index: true),
      Webhookdb::Services::Column.new(:status, "text"),
      Webhookdb::Services::Column.new(:transfer_reversal, "text", index: true),
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
      charge: obj_of_interest.fetch("charge"),
      created: self.tsat(obj_of_interest.fetch("created")),
      payment_intent: obj_of_interest.fetch("payment_intent"),
      receipt_number: obj_of_interest.fetch("receipt_number"),
      source_transfer_reversal: obj_of_interest.fetch("source_transfer_reversal"),
      status: obj_of_interest.fetch("status"),
      transfer_reversal: obj_of_interest.fetch("transfer_reversal"),
      updated: self.tsat(updated),
      stripe_id: obj_of_interest.fetch("id"),
    }
  end

  def _mixin_name_singular
    return "Stripe Refund"
  end

  def _mixin_name_plural
    return "Stripe Refunds"
  end

  def _mixin_backfill_url
    return "https://api.stripe.com/v1/refunds"
  end

  def _mixin_event_type_names
    return ["charge.refund.updated"]
  end
end
