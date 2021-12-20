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
      Webhookdb::Services::Column.new(:cancelled_at, "timestamptz"),
      Webhookdb::Services::Column.new(:cart_token, "text"),
      Webhookdb::Services::Column.new(:checkout_token, "text"),
      Webhookdb::Services::Column.new(:closed_at, "timestamptz"),
      Webhookdb::Services::Column.new(:created_at, "timestamptz"),
      Webhookdb::Services::Column.new(:customer_id, "text"),
      Webhookdb::Services::Column.new(:email, "text"),
      Webhookdb::Services::Column.new(:name, "text"),
      Webhookdb::Services::Column.new(:order_number, "integer"),
      Webhookdb::Services::Column.new(:phone, "text"),
      Webhookdb::Services::Column.new(:token, "text"),
      Webhookdb::Services::Column.new(:updated_at, "timestamptz"),
      Webhookdb::Services::Column.new(:user_id, "text"),
    ]
  end

  def _update_where_expr
    return Sequel[self.table_sym][:updated_at] < Sequel[:excluded][:updated_at]
  end

  def _prepare_for_insert(body, **_kwargs)
    return {
      app_id: body["app_id"],
      cancelled_at: body["cancelled_at"],
      cart_token: body["cart_token"],
      checkout_token: body["checkout_token"],
      closed_at: body["closed_at"],
      created_at: body["created_at"],
      customer_id: body["customer"]["id"],
      email: body["email"],
      name: body["name"],
      order_number: body["order_number"],
      phone: body["phone"],
      shopify_id: body["id"],
      token: body["token"],
      updated_at: body["updated_at"],
      user_id: body["user_id"],
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
Please email hello@lithic.tech if you need a complete history backfill.
)
  end
end
