# frozen_string_literal: true

require "stripe"
require "webhookdb/services/stripe_v1_mixin"

class Webhookdb::Services::StripeDisputeV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::StripeV1Mixin

  # @return [Webhookdb::Services::Descriptor]
  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "stripe_dispute_v1",
      ctor: ->(sint) { Webhookdb::Services::StripeDisputeV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "Stripe Dispute",
    )
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:stripe_id, TEXT, data_key: "id")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:amount, INTEGER),
      Webhookdb::Services::Column.new(:charge, TEXT),
      Webhookdb::Services::Column.new(:cancellation_policy, TEXT, data_key: ["evidence", "cancellation_policy"]),
      Webhookdb::Services::Column.new(:created, TIMESTAMP, index: true, converter: :tsat),
      Webhookdb::Services::Column.new(
        :due_by,
        TIMESTAMP,
        data_key: ["evidence_details", "due_by"],
        converter: :tsat,
      ),
      Webhookdb::Services::Column.new(:is_charge_refundable, TEXT),
      Webhookdb::Services::Column.new(:receipt, TEXT, data_key: ["evidence", "receipt"]),
      Webhookdb::Services::Column.new(:refund_policy, TEXT, data_key: ["evidence", "refund_policy"]),
      Webhookdb::Services::Column.new(
        :service_date,
        TIMESTAMP,
        data_key: ["evidence", "service_date"],
        converter: :tsat,
      ),
      Webhookdb::Services::Column.new(:status, TEXT),
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
    return "https://api.stripe.com/v1/disputes"
  end

  def _mixin_event_type_names
    return [
      "charge.dispute.closed",
      "charge.dispute.created",
      "charge.dispute.funds_reinstated",
      "charge.dispute.funds_withdrawn",
      "charge.dispute.updated",
    ]
  end
end
