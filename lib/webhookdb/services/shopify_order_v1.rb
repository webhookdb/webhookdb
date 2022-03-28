# frozen_string_literal: true

require "webhookdb/shopify"
require "webhookdb/services/shopify_v1_mixin"

class Webhookdb::Services::ShopifyOrderV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::ShopifyV1Mixin

  # @return [Webhookdb::Services::Descriptor]
  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "shopify_order_v1",
      ctor: ->(sint) { Webhookdb::Services::ShopifyOrderV1.new(sint) },
      feature_roles: [],
    )
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:shopify_id, "text")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:app_id, "text"),
      Webhookdb::Services::Column.new(:cancelled_at, "timestamptz", index: true),
      Webhookdb::Services::Column.new(:cart_token, "text"),
      Webhookdb::Services::Column.new(:checkout_token, "text"),
      Webhookdb::Services::Column.new(:closed_at, "timestamptz", index: true),
      Webhookdb::Services::Column.new(:created_at, "timestamptz", index: true),
      Webhookdb::Services::Column.new(:customer_id, "text", index: true),
      Webhookdb::Services::Column.new(:email, "text", index: true),
      Webhookdb::Services::Column.new(:name, "text"),
      Webhookdb::Services::Column.new(:order_number, "integer", index: true),
      Webhookdb::Services::Column.new(:phone, "text", index: true),
      Webhookdb::Services::Column.new(:token, "text"),
      Webhookdb::Services::Column.new(:updated_at, "timestamptz", index: true),
      Webhookdb::Services::Column.new(:user_id, "text", index: true),
    ]
  end

  def _update_where_expr
    return Sequel[self.table_sym][:updated_at] < Sequel[:excluded][:updated_at]
  end

  def _prepare_for_insert(body, **_kwargs)
    return {
      app_id: body.fetch("app_id"),
      cancelled_at: body.fetch("cancelled_at"),
      cart_token: body.fetch("cart_token"),
      checkout_token: body.fetch("checkout_token"),
      closed_at: body.fetch("closed_at"),
      created_at: body.fetch("created_at"),
      customer_id: body.dig("customer", "id"),
      email: body.fetch("email"),
      name: body.fetch("name"),
      order_number: body.fetch("order_number"),
      phone: body.fetch("phone"),
      shopify_id: body.fetch("id"),
      token: body.fetch("token"),
      updated_at: body.fetch("updated_at"),
      user_id: body.fetch("user_id"),
    }
  end

  def _mixin_name_singular
    return "Shopify Order"
  end

  def _mixin_name_plural
    return "Shopify Orders"
  end

  def _mixin_backfill_url
    return "/admin/api/2021-04/orders.json?status=any"
  end

  def _mixin_backfill_hashkey
    return "orders"
  end

  def _mixin_backfill_warning
    return %(Please note that Shopify only allows us to have access to orders made in the last 60 days,
so this history will not be comprehensive.
Please email webhookdb@lithic.tech if you need a complete history backfill.
)
  end
end
