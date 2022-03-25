# frozen_string_literal: true

require "stripe"
require "webhookdb/services/stripe_v1_mixin"

class Webhookdb::Services::StripeInvoiceV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::StripeV1Mixin

  # @return [Webhookdb::Services::Descriptor]
  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "stripe_invoice_v1",
      ctor: ->(sint) { Webhookdb::Services::StripeInvoiceV1.new(sint) },
      feature_roles: ["beta"],
    )
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:stripe_id, "text")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:amount_due, "integer"),
      Webhookdb::Services::Column.new(:amount_paid, "integer"),
      Webhookdb::Services::Column.new(:amount_remaining, "integer"),
      Webhookdb::Services::Column.new(:charge, "text"),
      Webhookdb::Services::Column.new(:created, "timestamptz"),
      Webhookdb::Services::Column.new(:customer, "text"),
      Webhookdb::Services::Column.new(:customer_address, "text"),
      Webhookdb::Services::Column.new(:customer_email, "text"),
      Webhookdb::Services::Column.new(:customer_name, "text"),
      Webhookdb::Services::Column.new(:customer_phone, "text"),
      Webhookdb::Services::Column.new(:customer_shipping, "text"),
      Webhookdb::Services::Column.new(:number, "text"),
      Webhookdb::Services::Column.new(:period_start, "timestamptz"),
      Webhookdb::Services::Column.new(:period_end, "timestamptz"),
      Webhookdb::Services::Column.new(:statement_descriptor, "text"),
      Webhookdb::Services::Column.new(:status, "text"),
      Webhookdb::Services::Column.new(:status_transitions_finalized_at, "timestamptz"),
      Webhookdb::Services::Column.new(:status_transitions_marked_uncollectible_at, "timestamptz"),
      Webhookdb::Services::Column.new(:status_transitions_marked_paid_at, "timestamptz"),
      Webhookdb::Services::Column.new(:status_transitions_voided_at, "timestamptz"),
      Webhookdb::Services::Column.new(:subtotal, "integer"),
      Webhookdb::Services::Column.new(:tax, "integer"),
      Webhookdb::Services::Column.new(:total, "integer"),
      Webhookdb::Services::Column.new(:updated, "timestamptz"),
    ]
  end

  def _update_where_expr
    return Sequel[self.table_sym][:updated] < Sequel[:excluded][:updated]
  end

  def _prepare_for_insert(body, **_kwargs)
    obj_of_interest, updated = self._extract_obj_and_updated(body)
    transitions = obj_of_interest.fetch("status_transitions") || {}
    return {
      data: obj_of_interest.to_json,
      amount_due: obj_of_interest.fetch("amount_due"),
      amount_paid: obj_of_interest.fetch("amount_paid"),
      amount_remaining: obj_of_interest.fetch("amount_remaining"),
      charge: obj_of_interest.fetch("charge"),
      created: self.tsat(obj_of_interest.fetch("created")),
      customer: obj_of_interest.fetch("customer"),
      customer_address: obj_of_interest.fetch("customer_address"),
      customer_email: obj_of_interest.fetch("customer_email"),
      customer_name: obj_of_interest.fetch("customer_name"),
      customer_phone: obj_of_interest.fetch("customer_phone"),
      customer_shipping: obj_of_interest.fetch("customer_shipping"),
      number: obj_of_interest.fetch("number"),
      period_start: self.tsat(obj_of_interest.fetch("period_start")),
      period_end: self.tsat(obj_of_interest.fetch("period_end")),
      statement_descriptor: obj_of_interest.fetch("statement_descriptor"),
      status: obj_of_interest.fetch("status"),
      status_transitions_finalized_at: self.tsat(transitions["status_transitions_finalized_at"]),
      status_transitions_marked_uncollectible_at: self.tsat(transitions["status_transitions_marked_uncollectible_at"]),
      status_transitions_marked_paid_at: self.tsat(transitions["status_transitions_marked_paid_at"]),
      status_transitions_voided_at: self.tsat(transitions["status_transitions_voided_at"]),
      subtotal: obj_of_interest.fetch("subtotal"),
      tax: obj_of_interest.fetch("tax"),
      total: obj_of_interest.fetch("total"),
      updated: self.tsat(updated),
      stripe_id: obj_of_interest.fetch("id"),
    }
  end

  def _mixin_name_singular
    return "Stripe Invoice"
  end

  def _mixin_name_plural
    return "Stripe Invoices"
  end

  def _mixin_backfill_url
    return "https://api.stripe.com/v1/invoices"
  end
end
