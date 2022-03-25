# frozen_string_literal: true

require "stripe"
require "webhookdb/services/stripe_v1_mixin"

class Webhookdb::Services::StripeInvoiceitemV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::StripeV1Mixin

  # @return [Webhookdb::Services::Descriptor]
  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "stripe_invoiceitem_v1",
      ctor: ->(sint) { Webhookdb::Services::StripeInvoiceitemV1.new(sint) },
      feature_roles: ["beta"],
    )
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:stripe_id, "text")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:amount, "integer"),
      Webhookdb::Services::Column.new(:customer, "text"),
      Webhookdb::Services::Column.new(:date, "timestamptz"),
      Webhookdb::Services::Column.new(:description, "text"),
      Webhookdb::Services::Column.new(:invoice, "text"),
      Webhookdb::Services::Column.new(:period_end, "timestamptz"),
      Webhookdb::Services::Column.new(:period_start, "timestamptz"),
      Webhookdb::Services::Column.new(:price, "text"),
      Webhookdb::Services::Column.new(:product, "text"),
      Webhookdb::Services::Column.new(:subscription, "text"),
      Webhookdb::Services::Column.new(:subscription_item, "text"),
      Webhookdb::Services::Column.new(:quantity, "integer"),
      Webhookdb::Services::Column.new(:unit_amount, "integer"),
      Webhookdb::Services::Column.new(:updated, "timestamptz"),
    ]
  end

  def _update_where_expr
    return Sequel[self.table_sym][:updated] < Sequel[:excluded][:updated]
  end

  def _prepare_for_insert(body, **_kwargs)
    obj_of_interest, updated = self._extract_obj_and_updated(body)
    period = obj_of_interest.fetch("period", {})
    price = obj_of_interest.fetch("price", {})
    return {
      data: obj_of_interest.to_json,
      amount: obj_of_interest.fetch("amount"),
      customer: obj_of_interest.fetch("customer"),
      date: self.tsat(obj_of_interest.fetch("date")),
      description: obj_of_interest.fetch("description"),
      invoice: obj_of_interest.fetch("invoice"),
      period_end: self.tsat(period["end"]),
      period_start: self.tsat(period["start"]),
      price: price["id"],
      product: price["product"],
      subscription: obj_of_interest.fetch("subscription"),
      subscription_item: obj_of_interest["subscription_item"], # In the docs, but not in their example
      quantity: obj_of_interest.fetch("quantity"),
      unit_amount: obj_of_interest.fetch("unit_amount"),
      updated: self.tsat(updated),
      stripe_id: obj_of_interest.fetch("id"),
    }
  end

  def _mixin_name_singular
    return "Stripe Invoiceitem"
  end

  def _mixin_name_plural
    return "Stripe Invoiceitems"
  end

  def _mixin_backfill_url
    return "https://api.stripe.com/v1/invoiceitems"
  end
end
