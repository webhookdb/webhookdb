# frozen_string_literal: true

require "webhookdb/shopify"
require "webhookdb/replicator/shopify_v1_mixin"

class Webhookdb::Replicator::ShopifyOrderV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::ShopifyV1Mixin

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "shopify_order_v1",
      ctor: ->(sint) { Webhookdb::Replicator::ShopifyOrderV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "Shopify Order",
      supports_webhooks: true,
      supports_backfill: true,
    )
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:shopify_id, TEXT, data_key: "id")
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:app_id, TEXT),
      Webhookdb::Replicator::Column.new(:cancelled_at, TIMESTAMP, index: true),
      Webhookdb::Replicator::Column.new(:cart_token, TEXT),
      Webhookdb::Replicator::Column.new(:checkout_token, TEXT),
      Webhookdb::Replicator::Column.new(:closed_at, TIMESTAMP, index: true),
      Webhookdb::Replicator::Column.new(:created_at, TIMESTAMP, index: true),
      Webhookdb::Replicator::Column.new(:customer_id, TEXT,
                                        index: true, data_key: ["customer", "id"], optional: true,),
      Webhookdb::Replicator::Column.new(:email, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:name, TEXT),
      Webhookdb::Replicator::Column.new(:order_number, INTEGER, index: true),
      Webhookdb::Replicator::Column.new(:phone, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:token, TEXT),
      Webhookdb::Replicator::Column.new(:updated_at, TIMESTAMP, index: true),
      Webhookdb::Replicator::Column.new(:user_id, TEXT, index: true),
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
