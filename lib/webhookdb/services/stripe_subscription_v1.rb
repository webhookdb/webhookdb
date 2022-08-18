# frozen_string_literal: true

require "stripe"
require "webhookdb/services/stripe_v1_mixin"

class Webhookdb::Services::StripeSubscriptionV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::StripeV1Mixin

  # @return [Webhookdb::Services::Descriptor]
  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "stripe_subscription_v1",
      ctor: ->(sint) { Webhookdb::Services::StripeSubscriptionV1.new(sint) },
      feature_roles: ["beta"],
      resource_name_singular: "Stripe Subscription",
    )
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:stripe_id, TEXT, data_key: "id")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:billing_cycle_anchor, TIMESTAMP, index: true, converter: :tsat),
      Webhookdb::Services::Column.new(:cancel_at, TIMESTAMP, index: true, optional: true, converter: :tsat),
      Webhookdb::Services::Column.new(:canceled_at, TIMESTAMP, index: true, optional: true, converter: :tsat),
      Webhookdb::Services::Column.new(:created, TIMESTAMP, index: true, converter: :tsat),
      Webhookdb::Services::Column.new(:current_period_end, TIMESTAMP, index: true, converter: :tsat),
      Webhookdb::Services::Column.new(:current_period_start, TIMESTAMP, index: true, converter: :tsat),
      Webhookdb::Services::Column.new(:customer, TEXT, index: true),
      Webhookdb::Services::Column.new(:default_payment_method, TEXT),
      Webhookdb::Services::Column.new(:default_source, TEXT),
      Webhookdb::Services::Column.new(:discount, TEXT, index: true),
      Webhookdb::Services::Column.new(:ended_at, TIMESTAMP, index: true, optional: true),
      Webhookdb::Services::Column.new(:latest_invoice, TEXT, index: true),
      Webhookdb::Services::Column.new(:schedule, TEXT, index: true),
      Webhookdb::Services::Column.new(:start_date, TIMESTAMP, index: true, converter: :tsat),
      Webhookdb::Services::Column.new(:status, TEXT),
      Webhookdb::Services::Column.new(:trial_end, TIMESTAMP, optional: true, converter: :tsat),
      Webhookdb::Services::Column.new(:trial_start, TIMESTAMP, optional: true, converter: :tsat),
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
