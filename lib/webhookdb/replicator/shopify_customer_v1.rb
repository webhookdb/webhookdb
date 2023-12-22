# frozen_string_literal: true

require "webhookdb/shopify"
require "webhookdb/replicator/shopify_v1_mixin"

class Webhookdb::Replicator::ShopifyCustomerV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::ShopifyV1Mixin

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "shopify_customer_v1",
      ctor: ->(sint) { Webhookdb::Replicator::ShopifyCustomerV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "Shopify Customer",
      supports_webhooks: true,
      supports_backfill: true,
      api_docs_url: "https://shopify.dev/docs/api/admin-rest/2023-10/resources/customer",
    )
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:shopify_id, TEXT, data_key: "id")
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:created_at,  TIMESTAMP, index: true),
      Webhookdb::Replicator::Column.new(:email, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:first_name, TEXT),
      Webhookdb::Replicator::Column.new(:last_name, TEXT),
      Webhookdb::Replicator::Column.new(:last_order_id, TEXT),
      Webhookdb::Replicator::Column.new(:last_order_name, TEXT),
      Webhookdb::Replicator::Column.new(:phone, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:state, TEXT),
      Webhookdb::Replicator::Column.new(:updated_at, TIMESTAMP, index: true),
    ]
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:updated_at] < Sequel[:excluded][:updated_at]
  end

  def _mixin_backfill_url
    return "/admin/api/2021-04/customers.json"
  end

  def _mixin_backfill_hashkey
    return "customers"
  end

  def _mixin_backfill_warning
    return %(Shopify allows us to backfill your entire Customer history,
so you're in good shape.
)
  end
end
