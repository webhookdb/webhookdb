# frozen_string_literal: true

require "stripe"
require "webhookdb/services/stripe_v1_mixin"

class Webhookdb::Services::StripeCustomerV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::StripeV1Mixin

  # @return [Webhookdb::Services::Descriptor]
  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "stripe_customer_v1",
      ctor: ->(sint) { Webhookdb::Services::StripeCustomerV1.new(sint) },
      feature_roles: [],
    )
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:stripe_id, "text")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:balance, "integer"),
      Webhookdb::Services::Column.new(:created, "timestamptz"),
      Webhookdb::Services::Column.new(:email, "text"),
      Webhookdb::Services::Column.new(:name, "text"),
      Webhookdb::Services::Column.new(:phone, "text"),
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
      balance: obj_of_interest.fetch("balance"),
      created: self.tsat(obj_of_interest.fetch("created")),
      email: obj_of_interest.fetch("email"),
      name: obj_of_interest.fetch("name"),
      phone: obj_of_interest.fetch("phone"),
      stripe_id: obj_of_interest.fetch("id"),
      updated: self.tsat(updated),
    }
  end

  def _mixin_name_singular
    return "Stripe Customer"
  end

  def _mixin_name_plural
    return "Stripe Customers"
  end

  def _mixin_backfill_url
    return "https://api.stripe.com/v1/customers"
  end
end
