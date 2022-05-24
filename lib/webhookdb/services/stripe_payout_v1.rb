# frozen_string_literal: true

require "stripe"
require "webhookdb/services/stripe_v1_mixin"

class Webhookdb::Services::StripePayoutV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::StripeV1Mixin

  # @return [Webhookdb::Services::Descriptor]
  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "stripe_payout_v1",
      ctor: ->(sint) { Webhookdb::Services::StripePayoutV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "Stripe Payout",
    )
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:stripe_id, TEXT)
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:amount, INTEGER, index: true),
      Webhookdb::Services::Column.new(:arrival_date, TIMESTAMP, index: true),
      Webhookdb::Services::Column.new(:balance_transaction, TEXT, index: true),
      Webhookdb::Services::Column.new(:created, TIMESTAMP, index: true),
      Webhookdb::Services::Column.new(:destination, TEXT, index: true),
      Webhookdb::Services::Column.new(:failure_balance_transaction, TEXT, index: true),
      Webhookdb::Services::Column.new(:original_payout, TEXT, index: true),
      Webhookdb::Services::Column.new(:reversed_by, TEXT, index: true),
      Webhookdb::Services::Column.new(:statement_descriptor, TEXT),
      Webhookdb::Services::Column.new(:status, TEXT),
      Webhookdb::Services::Column.new(:updated, TIMESTAMP, index: true),
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
      arrival_date: self.tsat(obj_of_interest.fetch("arrival_date")),
      balance_transaction: obj_of_interest.fetch("balance_transaction"),
      created: self.tsat(obj_of_interest.fetch("created")),
      destination: obj_of_interest.fetch("destination"),
      failure_balance_transaction: obj_of_interest.fetch("failure_balance_transaction"),
      original_payout: obj_of_interest.fetch("original_payout"),
      reversed_by: obj_of_interest.fetch("reversed_by"),
      statement_descriptor: obj_of_interest.fetch("statement_descriptor"),
      status: obj_of_interest.fetch("status"),
      updated: self.tsat(updated),
      stripe_id: obj_of_interest.fetch("id"),
    }
  end

  def _mixin_backfill_url
    return "https://api.stripe.com/v1/payouts"
  end

  def _mixin_event_type_names
    return [
      "payout.canceled",
      "payout.created",
      "payout.failed",
      "payout.paid",
      "payout.updated",
    ]
  end
end
