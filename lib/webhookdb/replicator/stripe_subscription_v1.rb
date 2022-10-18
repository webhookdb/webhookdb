# frozen_string_literal: true

require "stripe"
require "webhookdb/replicator/stripe_v1_mixin"

class Webhookdb::Replicator::StripeSubscriptionV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::StripeV1Mixin

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "stripe_subscription_v1",
      ctor: ->(sint) { Webhookdb::Replicator::StripeSubscriptionV1.new(sint) },
      feature_roles: ["beta"],
      resource_name_singular: "Stripe Subscription",
    )
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:stripe_id, TEXT, data_key: "id")
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:billing_cycle_anchor, TIMESTAMP, index: true, converter: :tsat),
      Webhookdb::Replicator::Column.new(:cancel_at, TIMESTAMP, index: true, optional: true, converter: :tsat),
      Webhookdb::Replicator::Column.new(:canceled_at, TIMESTAMP, index: true, optional: true, converter: :tsat),
      Webhookdb::Replicator::Column.new(:created, TIMESTAMP, index: true, converter: :tsat),
      Webhookdb::Replicator::Column.new(:current_period_end, TIMESTAMP, index: true, converter: :tsat),
      Webhookdb::Replicator::Column.new(:current_period_start, TIMESTAMP, index: true, converter: :tsat),
      Webhookdb::Replicator::Column.new(:customer, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:default_payment_method, TEXT),
      Webhookdb::Replicator::Column.new(:default_source, TEXT),
      Webhookdb::Replicator::Column.new(:discount, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:ended_at, TIMESTAMP, index: true, optional: true),
      Webhookdb::Replicator::Column.new(:latest_invoice, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:schedule, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:start_date, TIMESTAMP, index: true, converter: :tsat),
      Webhookdb::Replicator::Column.new(:status, TEXT),
      Webhookdb::Replicator::Column.new(:trial_end, TIMESTAMP, optional: true, converter: :tsat),
      Webhookdb::Replicator::Column.new(:trial_start, TIMESTAMP, optional: true, converter: :tsat),
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
    return "https://api.stripe.com/v1/subscriptions"
  end

  def _mixin_event_type_names
    return [
      "customer.subscription.created",
      "customer.subscription.deleted",
      "customer.subscription.pending_update_applied",
      "customer.subscription.pending_update_expired",
      "customer.subscription.trial_will_end",
      "customer.subscription.updated",
    ]
  end
end
