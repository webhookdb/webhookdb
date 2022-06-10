# frozen_string_literal: true

require "stripe"
require "webhookdb/services/stripe_v1_mixin"

class Webhookdb::Services::StripeInvoiceItemV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::StripeV1Mixin

  # @return [Webhookdb::Services::Descriptor]
  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "stripe_invoice_item_v1",
      ctor: ->(sint) { Webhookdb::Services::StripeInvoiceItemV1.new(sint) },
      feature_roles: ["beta"],
      resource_name_singular: "Stripe Invoice Item",
    )
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:stripe_id, TEXT)
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:amount, INTEGER, index: true),
      Webhookdb::Services::Column.new(:customer, TEXT, index: true),
      Webhookdb::Services::Column.new(:date, TIMESTAMP, index: true),
      Webhookdb::Services::Column.new(:description, TEXT),
      Webhookdb::Services::Column.new(:invoice, TEXT, index: true),
      Webhookdb::Services::Column.new(:period_end, TIMESTAMP, index: true),
      Webhookdb::Services::Column.new(:period_start, TIMESTAMP, index: true),
      Webhookdb::Services::Column.new(:price, TEXT, index: true),
      Webhookdb::Services::Column.new(:product, TEXT, index: true),
      Webhookdb::Services::Column.new(:subscription, TEXT, index: true),
      Webhookdb::Services::Column.new(:subscription_item, TEXT, index: true),
      Webhookdb::Services::Column.new(:quantity, INTEGER),
      Webhookdb::Services::Column.new(:unit_amount, INTEGER),
      Webhookdb::Services::Column.new(:updated, TIMESTAMP, index: true),
    ]
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:updated] < Sequel[:excluded][:updated]
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

  def _mixin_backfill_url
    return "https://api.stripe.com/v1/invoiceitems"
  end

  def _mixin_event_type_names
    return [
      "invoiceitem.created",
      "invoiceitem.deleted",
      "invoiceitem.updated",
    ]
  end
end
