# frozen_string_literal: true

require "stripe"
require "webhookdb/services/stripe_v1_mixin"

class Webhookdb::Services::StripeProductV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::StripeV1Mixin

  # @return [Webhookdb::Services::Descriptor]
  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "stripe_product_v1",
      ctor: ->(sint) { Webhookdb::Services::StripeProductV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "Stripe Product",
    )
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:stripe_id, "text")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:created, "timestamptz"),
      Webhookdb::Services::Column.new(:name, "text"),
      Webhookdb::Services::Column.new(:package_dimensions, "text"),
      Webhookdb::Services::Column.new(:statement_descriptor, "text"),
      Webhookdb::Services::Column.new(:unit_label, "text"),
      Webhookdb::Services::Column.new(:updated, "timestamptz"),
    ]
  end

  def _update_where_expr
    return Sequel[self.table_sym][:updated] < Sequel[:excluded][:updated]
  end

  def _prepare_for_insert(body, **_kwargs)
    obj_of_interest, updated = self._extract_obj_and_updated(body)
    return {
      data: obj_of_interest.to_json,
      created: self.tsat(obj_of_interest.fetch("created")),
      name: obj_of_interest.fetch("name"),
      package_dimensions: obj_of_interest.fetch("package_dimensions"),
      statement_descriptor: obj_of_interest.fetch("statement_descriptor"),
      unit_label: obj_of_interest.fetch("unit_label"),
      updated: self.tsat(updated),
      stripe_id: obj_of_interest.fetch("id"),
    }
  end

  def _mixin_backfill_url
    return "https://api.stripe.com/v1/products"
  end

  def _mixin_event_type_names
    return [
      "product.created",
      "product.deleted",
      "product.updated",
    ]
  end
end
