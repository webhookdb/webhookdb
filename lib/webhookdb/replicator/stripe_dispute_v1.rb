# frozen_string_literal: true

require "stripe"
require "webhookdb/replicator/stripe_v1_mixin"

class Webhookdb::Replicator::StripeDisputeV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::StripeV1Mixin

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "stripe_dispute_v1",
      ctor: ->(sint) { Webhookdb::Replicator::StripeDisputeV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "Stripe Dispute",
      supports_webhooks: true,
      supports_backfill: true,
      api_docs_url: "https://stripe.com/docs/api/disputes",
    )
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:stripe_id, TEXT, data_key: "id")
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:amount, INTEGER),
      Webhookdb::Replicator::Column.new(:charge, TEXT),
      Webhookdb::Replicator::Column.new(:cancellation_policy, TEXT, data_key: ["evidence", "cancellation_policy"]),
      Webhookdb::Replicator::Column.new(:created, TIMESTAMP, index: true, converter: :tsat),
      Webhookdb::Replicator::Column.new(
        :due_by,
        TIMESTAMP,
        data_key: ["evidence_details", "due_by"],
        converter: :tsat,
      ),
      Webhookdb::Replicator::Column.new(:is_charge_refundable, TEXT),
      Webhookdb::Replicator::Column.new(:receipt, TEXT, data_key: ["evidence", "receipt"]),
      Webhookdb::Replicator::Column.new(:refund_policy, TEXT, data_key: ["evidence", "refund_policy"]),
      Webhookdb::Replicator::Column.new(
        :service_date,
        TIMESTAMP,
        data_key: ["evidence", "service_date"],
        converter: :tsat,
      ),
      Webhookdb::Replicator::Column.new(:status, TEXT),
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
