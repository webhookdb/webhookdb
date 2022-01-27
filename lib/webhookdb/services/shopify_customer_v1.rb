# frozen_string_literal: true

require "webhookdb/shopify"
require "webhookdb/services/shopify_v1_mixin"

class Webhookdb::Services::ShopifyCustomerV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::ShopifyV1Mixin

  # @return [Webhookdb::Services::Descriptor]
  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "shopify_customer_v1",
      ctor: ->(sint) { Webhookdb::Services::ShopifyCustomerV1.new(sint) },
      feature_roles: [],
    )
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:shopify_id, "text")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:created_at, "timestamptz"),
      Webhookdb::Services::Column.new(:email, "text"),
      Webhookdb::Services::Column.new(:first_name, "text"),
      Webhookdb::Services::Column.new(:last_name, "text"),
      Webhookdb::Services::Column.new(:last_order_id, "text"),
      Webhookdb::Services::Column.new(:last_order_name, "text"),
      Webhookdb::Services::Column.new(:phone, "text"),
      Webhookdb::Services::Column.new(:state, "text"),
      Webhookdb::Services::Column.new(:updated_at, "timestamptz"),
    ]
  end

  def _update_where_expr
    return Sequel[self.table_sym][:updated_at] < Sequel[:excluded][:updated_at]
  end

  def _prepare_for_insert(body, **_kwargs)
    return {
      created_at: body.fetch("created_at"),
      email: body.fetch("email"),
      first_name: body.fetch("first_name"),
      last_name: body.fetch("last_name"),
      last_order_id: body.fetch("last_order_id"),
      last_order_name: body.fetch("last_order_name"),
      phone: body.fetch("phone"),
      shopify_id: body.fetch("id"),
      state: body.fetch("state"),
      updated_at: body.fetch("updated_at"),
    }
  end

  def _mixin_name_singular
    return "Shopify Customer"
  end

  def _mixin_name_plural
    return "Shopify Customers"
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
