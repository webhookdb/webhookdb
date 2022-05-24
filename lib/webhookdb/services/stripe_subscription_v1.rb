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
      resource_name_singular: "Stripe Subscription",
    )
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:stripe_id, TEXT)
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:billing_cycle_anchor, TIMESTAMP, index: true),
      Webhookdb::Services::Column.new(:cancel_at, TIMESTAMP, index: true),
      Webhookdb::Services::Column.new(:canceled_at, TIMESTAMP, index: true),
      Webhookdb::Services::Column.new(:created, TIMESTAMP, index: true),
      Webhookdb::Services::Column.new(:current_period_end, TIMESTAMP, index: true),
      Webhookdb::Services::Column.new(:current_period_start, TIMESTAMP, index: true),
      Webhookdb::Services::Column.new(:customer, TEXT, index: true),
      Webhookdb::Services::Column.new(:default_payment_method, TEXT),
      Webhookdb::Services::Column.new(:default_source, TEXT),
      Webhookdb::Services::Column.new(:discount, TEXT, index: true),
      Webhookdb::Services::Column.new(:ended_at, TIMESTAMP, index: true),
      Webhookdb::Services::Column.new(:latest_invoice, TEXT, index: true),
      Webhookdb::Services::Column.new(:schedule, TEXT, index: true),
      Webhookdb::Services::Column.new(:start_date, TIMESTAMP, index: true),
      Webhookdb::Services::Column.new(:status, TEXT),
      Webhookdb::Services::Column.new(:trial_end, TIMESTAMP),
      Webhookdb::Services::Column.new(:trial_start, TIMESTAMP),
      Webhookdb::Services::Column.new(:updated, TIMESTAMP, index: true),
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

  def _mixin_backfill_url
    return "https://api.stripe.com/v1/subscriptions"
  end

  def _mixin_event_type_names
    return [
      "customer.subscription.created",
      "customer.subscription.deleted",
      "customer.subscription.pending_update_applied",
      "customer.subscription.pending_update_expired",
      "customer.subscription.trial_will_end",
      "customer.subscription.updated",
    ]
  end
end
