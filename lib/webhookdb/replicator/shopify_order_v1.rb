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
      resource_name_singular: "Shopify Order",
    )
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:shopify_id, TEXT, data_key: "id")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:app_id, TEXT),
      Webhookdb::Services::Column.new(:cancelled_at, TIMESTAMP, index: true),
      Webhookdb::Services::Column.new(:cart_token, TEXT),
      Webhookdb::Services::Column.new(:checkout_token, TEXT),
      Webhookdb::Services::Column.new(:closed_at, TIMESTAMP, index: true),
      Webhookdb::Services::Column.new(:created_at, TIMESTAMP, index: true),
      Webhookdb::Services::Column.new(:customer_id, TEXT, index: true, data_key: ["customer", "id"]),
      Webhookdb::Services::Column.new(:email, TEXT, index: true),
      Webhookdb::Services::Column.new(:name, TEXT),
      Webhookdb::Services::Column.new(:order_number, INTEGER, index: true),
      Webhookdb::Services::Column.new(:phone, TEXT, index: true),
      Webhookdb::Services::Column.new(:token, TEXT),
      Webhookdb::Services::Column.new(:updated_at, TIMESTAMP, index: true),
      Webhookdb::Services::Column.new(:user_id, TEXT, index: true),
    ]
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:updated_at] < Sequel[:excluded][:updated_at]
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
