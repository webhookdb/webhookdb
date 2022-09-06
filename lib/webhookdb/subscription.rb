# frozen_string_literal: true

class Webhookdb::Subscription < Webhookdb::Postgres::Model(:subscriptions)
  extend Webhookdb::MethodUtilities
  include Appydays::Configurable
  include Appydays::Loggable

  class Plan
    attr_accessor :key, :description, :price, :stripe_price_id, :stripe_product_id

    def initialize(key, stripe_price)
      @key = key
      @description = stripe_price.nickname
      @price = Money.new(stripe_price.unit_amount)
      @stripe_price_id = stripe_price.id
      @stripe_product_id = stripe_price.product
    end

    def as_json
      return {key:, description:, price:}
    end
  end

  plugin :timestamps
  plugin :soft_deletes

  configurable(:subscription) do
    setting :disable_billing, false
    setting :max_free_integrations, 2

    after_configured do
      self.max_free_integrations = 9999 if self.disable_billing
    end
  end

  one_to_one :organization, class: "Webhookdb::Organization", key: :stripe_customer_id, primary_key: :stripe_customer_id

  def self.billing_disabled?
    return self.disable_billing
  end

  def self.list_plans
    return [] if self.billing_disabled?
    prices = Stripe::Price.list(active: true)
    monthly = prices.find { |pr| pr.recurring.interval == "month" }
    yearly = prices.find { |pr| pr.recurring.interval == "year" }
    raise "Expected month and year prices in: #{prices.to_json}" unless monthly && yearly
    return [Plan.new("monthly", monthly), Plan.new("yearly", yearly)]
  end

  def initialize(*)
    super
    self[:stripe_json] ||= Sequel.pg_json({})
  end

  def status
    return self.stripe_json["status"]
  end

  def plan_name
    return self.stripe_json.dig("plan", "nickname") || ""
  end

  def self.create_or_update_from_stripe_hash(obj)
    created = false
    orig_status = nil
    sub = self.update_or_create(stripe_id: obj.fetch("id")) do |o|
      o.stripe_customer_id = obj.fetch("customer")
      if o.new?
        created = true
      else
        orig_status = o.status
      end
      o.stripe_json = obj.to_json
    end
    common_fields = [
      {title: "Subscription", value: sub.id, short: true},
      {title: "Status", value: sub.status, short: true},
      {title: "Stripe ID", value: sub.stripe_id, short: true},
      {title: "Customer ID", value: sub.stripe_customer_id, short: true},
    ]
    if sub.organization.nil?
      Webhookdb::DeveloperAlert.new(
        subsystem: "Subscription Error",
        emoji: ":hook:",
        fallback: "Subscription with Stripe ID #{sub.stripe_id} has no organization",
        fields: common_fields + [
          {title: "Message", value: "Has no organization in WebhookDB", short: false},
        ],
      ).emit
    elsif created
      Webhookdb::DeveloperAlert.new(
        subsystem: "Subscription Created",
        emoji: ":hook:",
        fallback: "Subscription with Stripe ID #{sub.stripe_id} created",
        fields: common_fields + [
          {title: "Organization", value: sub.organization.display_string, short: true},
          {title: "Message", value: "Created", short: true},
        ],
      ).emit
      elsif orig_status != sub.status
        Webhookdb::DeveloperAlert.new(
          subsystem: "Subscription Status Change",
          emoji: ":hook:",
          fallback: "Subscription with Stripe ID #{sub.stripe_id} changed status",
          fields: common_fields + [
            {title: "Organization", value: sub.organization.display_string, short: true},
            {title: "Message", value: "Status updated", short: true},
          ],
        ).emit
    end
    return sub
  end

  def self.create_or_update_from_webhook(webhook_body)
    obj = webhook_body["data"]["object"]
    self.create_or_update_from_stripe_hash(obj)
  end

  def self.create_or_update_from_id(id)
    subscription_obj = Stripe::Subscription.retrieve(id)
    self.create_or_update_from_stripe_hash(subscription_obj.as_json)
  end

  class Status
    attr_reader :data

    def initialize(**kw)
      @data = kw
    end

    def display_headers
      return [
        [:organization_formatted, "Organization"],
        [:billing_email, "Billing email"],
        [:plan_name, "Plan name"],
        [:integrations_used_formatted, "Integrations used"],
        [:integrations_remaining_formatted, "Integrations left"],
        [:sub_status, "Status"],
      ]
    end

    def message
      return "Use `webhookdb subscription edit` to set up or modify your subscription."
    end

    def as_json(*_o)
      return @data.merge(message: self.message,        display_headers: self.display_headers)
    end
  end

  def self.status_for_org(org)
    service_integrations = org.service_integrations
    used = service_integrations.count
    data = {
      organization_name: org.name,
      organization_key: org.key,
      organization_formatted: org.display_string,
      billing_email: org.billing_email,
      integrations_used: used,
      integrations_used_formatted: used.to_s,
    }
    subscription = Webhookdb::Subscription[stripe_customer_id: org.stripe_customer_id]
    # TODO: Modify the Stripe JSON to store the values of the fields for paid plans,
    # rather than hard-coding them.
    if subscription.nil?
      data[:plan_name] = "Free"
      data[:integrations_remaining] = [0, Webhookdb::Subscription.max_free_integrations - used].max
      data[:integrations_remaining_formatted] = data[:integrations_remaining].to_s
      data[:sub_status] = ""
    else
      data[:plan_name] = subscription.plan_name
      data[:integrations_remaining] = 2_000_000_000
      data[:integrations_remaining_formatted] = "unlimited"
      data[:sub_status] = subscription.status
    end
    return Status.new(**data)
  end

  def self.backfill_from_stripe(limit: 50, page_size: 50)
    subs = Stripe::Subscription.list({limit: page_size})
    done = 0
    subs.auto_paging_each do |sub|
      self.create_or_update_from_stripe_hash(sub.as_json)
      done += 1
      break if !limit.nil? && done >= limit
    end
  end
end

# Table: subscriptions
# ---------------------------------------------------------------------------------------------
# Columns:
#  id                 | integer                  | PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY
#  created_at         | timestamp with time zone | NOT NULL DEFAULT now()
#  updated_at         | timestamp with time zone |
#  soft_deleted_at    | timestamp with time zone |
#  stripe_id          | text                     | NOT NULL
#  stripe_customer_id | text                     | NOT NULL DEFAULT ''::text
#  stripe_json        | jsonb                    | DEFAULT '{}'::jsonb
# Indexes:
#  subscriptions_pkey                     | PRIMARY KEY btree (id)
#  subscriptions_stripe_id_key            | UNIQUE btree (stripe_id)
#  subscriptions_stripe_customer_id_index | btree (stripe_customer_id)
# ---------------------------------------------------------------------------------------------
