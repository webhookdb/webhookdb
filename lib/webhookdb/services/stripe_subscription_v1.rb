# frozen_string_literal: true

require "stripe"
require "webhookdb/services/stripe_v1_mixin"

class Webhookdb::Services::StripeSubscriptionV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::StripeV1Mixin

  # @return [Webhookdb::Services::Descriptor]
  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "stripe_subscription_v1",
      ctor: ->(sint) { Webhookdb::Services::StripeSubscriptionV1.new(sint) },
      feature_roles: ["beta"],
    )
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:stripe_id, "text")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:billing_cycle_anchor, "timestamptz"),
      Webhookdb::Services::Column.new(:cancel_at, "timestamptz"),
      Webhookdb::Services::Column.new(:canceled_at, "timestamptz"),
      Webhookdb::Services::Column.new(:created, "timestamptz"),
      Webhookdb::Services::Column.new(:current_period_end, "timestamptz"),
      Webhookdb::Services::Column.new(:current_period_start, "timestamptz"),
      Webhookdb::Services::Column.new(:customer, "text"),
      Webhookdb::Services::Column.new(:default_payment_method, "text"),
      Webhookdb::Services::Column.new(:default_source, "text"),
      Webhookdb::Services::Column.new(:discount, "text"),
      Webhookdb::Services::Column.new(:ended_at, "timestamptz"),
      Webhookdb::Services::Column.new(:latest_invoice, "text"),
      Webhookdb::Services::Column.new(:schedule, "text"),
      Webhookdb::Services::Column.new(:start_date, "timestamptz"),
      Webhookdb::Services::Column.new(:status, "text"),
      Webhookdb::Services::Column.new(:trial_end, "timestamptz"),
      Webhookdb::Services::Column.new(:trial_start, "timestamptz"),
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
      billing_cycle_anchor: self.tsat(obj_of_interest.fetch("billing_cycle_anchor")),
      cancel_at: self.tsat(obj_of_interest.fetch("cancel_at")),
      canceled_at: self.tsat(obj_of_interest.fetch("canceled_at")),
      created: self.tsat(obj_of_interest.fetch("created")),
      current_period_end: self.tsat(obj_of_interest.fetch("current_period_end")),
      current_period_start: self.tsat(obj_of_interest.fetch("current_period_start")),
      customer: obj_of_interest.fetch("customer"),
      default_payment_method: obj_of_interest.fetch("default_payment_method"),
      latest_invoice: obj_of_interest.fetch("latest_invoice"),
      schedule: obj_of_interest.fetch("schedule"),
      start_date: self.tsat(obj_of_interest.fetch("start_date")),
      status: obj_of_interest.fetch("status"),
      trial_end: self.tsat(obj_of_interest.fetch("trial_end")),
      trial_start: self.tsat(obj_of_interest.fetch("trial_start")),
      updated: self.tsat(updated),
      stripe_id: obj_of_interest.fetch("id"),
    }
  end

  def _mixin_name_singular
    return "Stripe Subscription"
  end

  def _mixin_name_plural
    return "Stripe Subscriptions"
  end

  def _mixin_backfill_url
    return "https://api.stripe.com/v1/subscriptions"
  end
end
