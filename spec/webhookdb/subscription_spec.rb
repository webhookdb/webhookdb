# frozen_string_literal: true

require "webhookdb/subscription"

RSpec.describe "Webhookdb::Subscription", :db do
  let(:described_class) { Webhookdb::Subscription }

  describe "create_or_update" do
    let(:webhook_data) do
      {"data" =>
          {"object" =>
              {"id" => "sub_JigYoW2aRYfl0R",
               "object" => "subscription",
               "application_fee_percent" => nil,
               "automatic_tax" =>
                  {"enabled" => false},
               "billing" => "charge_automatically",
               "billing_cycle_anchor" => 1_624_389_749,
               "billing_thresholds" => nil,
               "cancel_at" => nil,
               "cancel_at_period_end" => false,
               "canceled_at" => nil,
               "collection_method" => "charge_automatically",
               "created" => 1_624_389_749,
               "current_period_end" => 1_626_981_749,
               "current_period_start" => 1_624_389_749,
               "customer" => "cus_JR8V3eF6JmvjKZ",
               "days_until_due" => nil,
               "default_payment_method" => nil,
               "default_source" => nil,
               "default_tax_rates" => [],
               "discount" => nil,
               "ended_at" => nil,
               "invoice_customer_balance_settings" =>
                  {"consume_applied_balance_on_void" => true},
               "items" =>
                  {"object" => "list",
                   "data" => [
                     {"id" => "si_JigYnp1pfGlMbs",
                      "object" => "subscription_item",
                      "billing_thresholds" => nil,
                      "created" => 1_624_389_749,
                      "metadata" => {

                      },
                      "plan" =>
                         {"id" => "price_1J4s6rFFYxHXGyKx5NqSpSYB",
                          "object" => "plan",
                          "active" => true,
                          "aggregate_usage" => nil,
                          "amount" => 2500,
                          "amount_decimal" => "2500",
                          "billing_scheme" => "per_unit",
                          "created" => 1_624_301_077,
                          "currency" => "usd",
                          "interval" => "month",
                          "interval_count" => 1,
                          "livemode" => false,
                          "metadata" => {

                          },
                          "nickname" => nil,
                          "product" => "prod_JiIi6yyo7A3cha",
                          "tiers" => nil,
                          "tiers_mode" => nil,
                          "transform_usage" => nil,
                          "trial_period_days" => nil,
                          "usage_type" => "licensed",},
                      "price" =>
                         {"id" => "price_1J4s6rFFYxHXGyKx5NqSpSYB",
                          "object" => "price",
                          "active" => true,
                          "billing_scheme" => "per_unit",
                          "created" => 1_624_301_077,
                          "currency" => "usd",
                          "livemode" => false,
                          "lookup_key" => nil,
                          "metadata" => {

                          },
                          "nickname" => nil,
                          "product" => "prod_JiIi6yyo7A3cha",
                          "recurring" =>
                             {"aggregate_usage" => nil,
                              "interval" => "month",
                              "interval_count" => 1,
                              "trial_period_days" => nil,
                              "usage_type" => "licensed",},
                          "tiers_mode" => nil,
                          "transform_quantity" => nil,
                          "type" => "recurring",
                          "unit_amount" => 2500,
                          "unit_amount_decimal" => "2500",},
                      "quantity" => 1,
                      "subscription" => "sub_JigYoW2aRYfl0R",
                      "tax_rates" => [],},
                   ],
                   "has_more" => false,
                   "total_count" => 1,
                   "url" => "/v1/subscription_items?subscription=sub_JigYoW2aRYfl0R",},
               "latest_invoice" => "in_1J5FB3FFYxHXGyKxLCTiXLJY",
               "livemode" => false,
               "metadata" => {

               },
               "next_pending_invoice_item_invoice" => nil,
               "pause_collection" => nil,
               "pending_invoice_item_interval" => nil,
               "pending_setup_intent" => nil,
               "pending_update" => nil,
               "plan" =>
                  {"id" => "price_1J4s6rFFYxHXGyKx5NqSpSYB",
                   "object" => "plan",
                   "active" => true,
                   "aggregate_usage" => nil,
                   "amount" => 2500,
                   "amount_decimal" => "2500",
                   "billing_scheme" => "per_unit",
                   "created" => 1_624_301_077,
                   "currency" => "usd",
                   "interval" => "month",
                   "interval_count" => 1,
                   "livemode" => false,
                   "metadata" => {

                   },
                   "nickname" => nil,
                   "product" => "prod_JiIi6yyo7A3cha",
                   "tiers" => nil,
                   "tiers_mode" => nil,
                   "transform_usage" => nil,
                   "trial_period_days" => nil,
                   "usage_type" => "licensed",},
               "quantity" => 1,
               "schedule" => nil,
               "start" => 1_624_397_153,
               "start_date" => 1_624_389_749,
               "status" => "active",
               "tax_percent" => nil,
               "transfer_data" => nil,
               "trial_end" => nil,
               "trial_start" => nil,}}}
    end

    it "creates a subscription for a given org if one doesn't exist" do
      Webhookdb::Subscription.create_or_update_from_webhook(webhook_data)

      sub = Webhookdb::Subscription[stripe_id: "sub_JigYoW2aRYfl0R"]
      expect(sub).to_not be_nil
    end
    it "updates the subscription status of an existing subscription" do
      Webhookdb::Fixtures.subscription.create(stripe_id: "sub_JigYoW2aRYfl0R")
      Webhookdb::Subscription.create_or_update_from_webhook(webhook_data)

      sub = Webhookdb::Subscription[stripe_id: "sub_JigYoW2aRYfl0R"]
      expect(sub).to_not be_nil
      expect(sub.stripe_customer_id).to eq("cus_JR8V3eF6JmvjKZ")
      expect(sub.stripe_json).to have_key("status")
    end
  end

  describe "status_for_org" do
    let!(:org) { Webhookdb::Fixtures.organization.create }

    it "returns correct information if subscription does not exist" do
      data = Webhookdb::Subscription.status_for_org(org)

      expect(data[:org_name]).to eq(org.name)
      expect(data[:billing_email]).to eq("")
      expect(data[:integrations_used]).to eq("0")
      expect(data[:plan_name]).to eq("Free")
      expect(data[:integrations_left]).to eq(Webhookdb::Subscription.max_free_integrations.to_s)
      expect(data[:sub_status]).to eq("")
    end

    it "returns correct information if subscription exists" do
      org.update(billing_email: "santa@northpole.org")
      Webhookdb::Fixtures.subscription.active.for_org(org).create
      Webhookdb::Fixtures.service_integration.create(organization: org)

      data = Webhookdb::Subscription.status_for_org(org)
      expect(data[:org_name]).to eq(org.name)
      expect(data[:billing_email]).to eq("santa@northpole.org")
      expect(data[:integrations_used]).to eq("1")
      expect(data[:plan_name]).to eq("Premium")
      expect(data[:integrations_left]).to eq("unlimited")
      expect(data[:sub_status]).to eq("active")
    end
  end
end
