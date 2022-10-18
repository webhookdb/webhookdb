# frozen_string_literal: true

require "stripe"
require "webhookdb/replicator/stripe_v1_mixin"

class Webhookdb::Replicator::StripeCouponV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::StripeV1Mixin

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "stripe_coupon_v1",
      ctor: ->(sint) { Webhookdb::Replicator::StripeCouponV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "Stripe Coupon",
    )
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:stripe_id, TEXT, data_key: "id")
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:amount_off, TEXT),
      Webhookdb::Replicator::Column.new(:created, TIMESTAMP, index: true, event_key: "created", converter: :tsat),
      Webhookdb::Replicator::Column.new(:duration, TEXT),
      Webhookdb::Replicator::Column.new(:max_redemptions, INTEGER),
      Webhookdb::Replicator::Column.new(:name, TEXT),
      Webhookdb::Replicator::Column.new(:percent_off, DECIMAL),
      Webhookdb::Replicator::Column.new(:times_redeemed, DECIMAL),
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
    return "https://api.stripe.com/v1/coupons"
  end

  def _mixin_event_type_names
    return [
      "coupon.created",
      "coupon.deleted",
      "coupon.updated",
    ]
  end
end
