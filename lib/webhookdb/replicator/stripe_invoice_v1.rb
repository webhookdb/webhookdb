# frozen_string_literal: true

require "stripe"
require "webhookdb/replicator/stripe_v1_mixin"

class Webhookdb::Replicator::StripeInvoiceV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::StripeV1Mixin

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "stripe_invoice_v1",
      ctor: ->(sint) { Webhookdb::Replicator::StripeInvoiceV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "Stripe Invoice",
    )
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:stripe_id, TEXT, data_key: "id")
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:amount_due, INTEGER),
      Webhookdb::Replicator::Column.new(:amount_paid, INTEGER),
      Webhookdb::Replicator::Column.new(:amount_remaining, INTEGER),
      Webhookdb::Replicator::Column.new(:charge, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:created, TIMESTAMP, index: true, converter: :tsat),
      Webhookdb::Replicator::Column.new(:customer, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:customer_address, TEXT),
      Webhookdb::Replicator::Column.new(:customer_email, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:customer_name, TEXT),
      Webhookdb::Replicator::Column.new(:customer_phone, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:customer_shipping, TEXT),
      Webhookdb::Replicator::Column.new(:number, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:period_start, TIMESTAMP, index: true, converter: :tsat),
      Webhookdb::Replicator::Column.new(:period_end, TIMESTAMP, index: true, converter: :tsat),
      Webhookdb::Replicator::Column.new(:statement_descriptor, TEXT),
      Webhookdb::Replicator::Column.new(:status, TEXT),
      Webhookdb::Replicator::Column.new(
        :status_transitions_finalized_at,
        TIMESTAMP,
        index: true,
        data_key: ["status_transitions", "status_transitions_finalized_at"],
        optional: true,
        converter: :tsat,
      ),
      Webhookdb::Replicator::Column.new(
        :status_transitions_marked_uncollectible_at,
        TIMESTAMP,
        index: true,
        data_key: ["status_transitions", "status_transitions_marked_uncollectible_at"],
        optional: true,
        converter: :tsat,
      ),
      Webhookdb::Replicator::Column.new(
        :status_transitions_marked_paid_at,
        TIMESTAMP,
        index: true,
        data_key: ["status_transitions", "status_transitions_marked_paid_at"],
        optional: true,
        converter: :tsat,
      ),
      Webhookdb::Replicator::Column.new(
        :status_transitions_voided_at,
        TIMESTAMP,
        index: true,
        data_key: ["status_transitions", "status_transitions_voided_at"],
        optional: true,
        converter: :tsat,
      ),
      Webhookdb::Replicator::Column.new(:subtotal, INTEGER, index: true),
      Webhookdb::Replicator::Column.new(:tax, INTEGER, index: true),
      Webhookdb::Replicator::Column.new(:total, INTEGER, index: true),
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
