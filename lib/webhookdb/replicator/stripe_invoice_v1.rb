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
      resource_name_singular: "Stripe Invoice",
    )
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:stripe_id, TEXT, data_key: "id")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:amount_due, INTEGER),
      Webhookdb::Services::Column.new(:amount_paid, INTEGER),
      Webhookdb::Services::Column.new(:amount_remaining, INTEGER),
      Webhookdb::Services::Column.new(:charge, TEXT, index: true),
      Webhookdb::Services::Column.new(:created, TIMESTAMP, index: true, converter: :tsat),
      Webhookdb::Services::Column.new(:customer, TEXT, index: true),
      Webhookdb::Services::Column.new(:customer_address, TEXT),
      Webhookdb::Services::Column.new(:customer_email, TEXT, index: true),
      Webhookdb::Services::Column.new(:customer_name, TEXT),
      Webhookdb::Services::Column.new(:customer_phone, TEXT, index: true),
      Webhookdb::Services::Column.new(:customer_shipping, TEXT),
      Webhookdb::Services::Column.new(:number, TEXT, index: true),
      Webhookdb::Services::Column.new(:period_start, TIMESTAMP, index: true, converter: :tsat),
      Webhookdb::Services::Column.new(:period_end, TIMESTAMP, index: true, converter: :tsat),
      Webhookdb::Services::Column.new(:statement_descriptor, TEXT),
      Webhookdb::Services::Column.new(:status, TEXT),
      Webhookdb::Services::Column.new(
        :status_transitions_finalized_at,
        TIMESTAMP,
        index: true,
        data_key: ["status_transitions", "status_transitions_finalized_at"],
        optional: true,
        converter: :tsat,
      ),
      Webhookdb::Services::Column.new(
        :status_transitions_marked_uncollectible_at,
        TIMESTAMP,
        index: true,
        data_key: ["status_transitions", "status_transitions_marked_uncollectible_at"],
        optional: true,
        converter: :tsat,
      ),
      Webhookdb::Services::Column.new(
        :status_transitions_marked_paid_at,
        TIMESTAMP,
        index: true,
        data_key: ["status_transitions", "status_transitions_marked_paid_at"],
        optional: true,
        converter: :tsat,
      ),
      Webhookdb::Services::Column.new(
        :status_transitions_voided_at,
        TIMESTAMP,
        index: true,
        data_key: ["status_transitions", "status_transitions_voided_at"],
        optional: true,
        converter: :tsat,
      ),
      Webhookdb::Services::Column.new(:subtotal, INTEGER, index: true),
      Webhookdb::Services::Column.new(:tax, INTEGER, index: true),
      Webhookdb::Services::Column.new(:total, INTEGER, index: true),
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
    return "https://api.stripe.com/v1/invoices"
  end

  def _mixin_event_type_names
    return [
      "invoice.created",
      "invoice.deleted",
      "invoice.finalization_failed",
      "invoice.finalized",
      "invoice.marked_uncollectible",
      "invoice.paid",
      "invoice.payment_action_required",
      "invoice.payment_failed",
      "invoice.payment_succeeded",
      "invoice.sent",
      "invoice.upcoming",
      "invoice.updated",
      "invoice.voided",
    ]
  end
end
