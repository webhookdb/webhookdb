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
    return Webhookdb::Services::Column.new(:stripe_id, TEXT)
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:amount_off, TEXT),
      Webhookdb::Services::Column.new(:created, TIMESTAMP),
      Webhookdb::Services::Column.new(:duration, TEXT),
      Webhookdb::Services::Column.new(:max_redemptions, INTEGER),
      Webhookdb::Services::Column.new(:name, TEXT),
      Webhookdb::Services::Column.new(:percent_off, DECIMAL),
      Webhookdb::Services::Column.new(:times_redeemed, DECIMAL),
      Webhookdb::Services::Column.new(:updated, TIMESTAMP),
    ]
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:updated] < Sequel[:excluded][:updated]
  end

  def _prepare_for_insert(body, **_kwargs)
    obj_of_interest, updated = self._extract_obj_and_updated(body)
    return {
      data: obj_of_interest.to_json,
      amount_off: obj_of_interest.fetch("amount_off"),
      created: self.tsat(obj_of_interest.fetch("created")),
      duration: obj_of_interest.fetch("duration"),
      max_redemptions: obj_of_interest.fetch("max_redemptions"),
      name: obj_of_interest.fetch("name"),
      percent_off: obj_of_interest.fetch("percent_off"),
      times_redeemed: obj_of_interest.fetch("times_redeemed"),
      updated: self.tsat(updated),
      stripe_id: obj_of_interest.fetch("id"),
    }
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
