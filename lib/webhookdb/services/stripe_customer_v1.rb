# frozen_string_literal: true

require "stripe"
require "webhookdb/services/stripe_v1_mixin"

class Webhookdb::Services::StripeCustomerV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::StripeV1Mixin

  def _remote_key_column
    return Webhookdb::Services::Column.new(:stripe_id, "text")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:balance, "real"),
      Webhookdb::Services::Column.new(:created, "integer"),
      Webhookdb::Services::Column.new(:email, "text"),
      Webhookdb::Services::Column.new(:name, "text"),
      Webhookdb::Services::Column.new(:phone, "text"),
      Webhookdb::Services::Column.new(:updated, "integer"),
    ]
  end

  def _update_where_expr
    return Sequel[self.table_sym][:updated] < Sequel[:excluded][:updated]
  end

  def _prepare_for_insert(body, **_kwargs)
    # When we are backfilling, we recieve information from the charge api, but when
    # we recieve a webhook we are getting that information from the events api. Because
    # of this, the data we get in each case will have a different shape. This conditional
    # at the beginning of the function accomodates that difference in shape and ensures
    # that information from a webhook will always supercede information obtained through
    # backfilling.
    updated = 0
    obj_of_interest = body
    if body["object"] == "event"
      updated = body["created"]
      obj_of_interest = body["data"]["object"]
    end
    return {
      data: obj_of_interest.to_json,
      balance: obj_of_interest["balance"],
      created: obj_of_interest["created"],
      email: obj_of_interest["email"],
      name: obj_of_interest["name"],
      phone: obj_of_interest["phone"],
      stripe_id: obj_of_interest["id"],
      updated: updated,
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
