# frozen_string_literal: true

require "stripe"
require "webhookdb/services/stripe_v1_mixin"

class Webhookdb::Services::StripeSubscriptionItemV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::StripeV1Mixin

  # @return [Webhookdb::Services::Descriptor]
  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "stripe_subscription_item_v1",
      ctor: ->(sint) { Webhookdb::Services::StripeSubscriptionItemV1.new(sint) },
      feature_roles: ["beta"],
      resource_name_singular: "Stripe Subscription Item",
    )
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:stripe_id, TEXT)
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:created, TIMESTAMP, index: true),
      Webhookdb::Services::Column.new(:price, TEXT, index: true),
      Webhookdb::Services::Column.new(:product, TEXT, index: true),
      Webhookdb::Services::Column.new(:quantity, INTEGER),
      Webhookdb::Services::Column.new(:subscription, TEXT, index: true),
      Webhookdb::Services::Column.new(:updated, TIMESTAMP, index: true),
    ]
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:updated] < Sequel[:excluded][:updated]
  end

  def _prepare_for_insert(body, **_kwargs)
    obj_of_interest, updated = self._extract_obj_and_updated(body)
    return {
      data: obj_of_interest.to_json,
      created: self.tsat(obj_of_interest.fetch("created")),
      price: obj_of_interest.fetch("price", {})["id"],
      product: obj_of_interest.fetch("price", {})["product"],
      quantity: obj_of_interest.fetch("quantity"),
      subscription: obj_of_interest.fetch("subscription"),
      updated: self.tsat(updated),
      stripe_id: obj_of_interest.fetch("id"),
    }
  end

  def _mixin_backfill_url
    return "https://api.stripe.com/v1/subscription_items"
  end

  def _mixin_event_type_names
    return []
  end
end
