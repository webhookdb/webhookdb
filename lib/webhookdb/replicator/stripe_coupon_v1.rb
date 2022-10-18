# frozen_string_literal: true

require "stripe"
require "webhookdb/services/stripe_v1_mixin"

class Webhookdb::Services::StripeCouponV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::StripeV1Mixin

  # @return [Webhookdb::Services::Descriptor]
  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "stripe_coupon_v1",
      ctor: ->(sint) { Webhookdb::Services::StripeCouponV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "Stripe Coupon",
    )
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:stripe_id, TEXT, data_key: "id")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:amount_off, TEXT),
      Webhookdb::Services::Column.new(:created, TIMESTAMP, index: true, event_key: "created", converter: :tsat),
      Webhookdb::Services::Column.new(:duration, TEXT),
      Webhookdb::Services::Column.new(:max_redemptions, INTEGER),
      Webhookdb::Services::Column.new(:name, TEXT),
      Webhookdb::Services::Column.new(:percent_off, DECIMAL),
      Webhookdb::Services::Column.new(:times_redeemed, DECIMAL),
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
