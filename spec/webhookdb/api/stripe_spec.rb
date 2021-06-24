# frozen_string_literal: true

require "webhookdb/api/stripe"
require "webhookdb/stripe"

RSpec.describe Webhookdb::API::Stripe, :db, :async  do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }

  let!(:org) { Webhookdb::Fixtures.organization.create }

  describe "POST /v1/stripe/webhook" do
    let(:webhook_secret) { "xyz" }
    let(:webhook_body) {
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
             "trial_start" => nil,}
         }
      }
    }
    let(:now) { Time.now }
    let(:webhook_headers) do
      stripe_signature = "t=" + now.to_i.to_s + ",v1=" # this is the interim value
      stripe_signature += Stripe::Webhook::Signature.compute_signature(now, webhook_body.to_json,
                                                                       webhook_secret,)
      { "Stripe-Signature" => stripe_signature }
      end

    before(:each) do
      Webhookdb::Stripe.webhook_secret = webhook_secret
      webhook_headers.each { |k, v| header k, v }
    end

    it "receives a webhook from stripe, validates it, and acknowledges it" do
      post "/v1/stripe/webhook", webhook_body
      expect(last_response).to have_status(200)
    end

    it "errors if the webhook can't be validated" do
      Webhookdb::Stripe.webhook_secret = "foobar"
      post "/v1/stripe/webhook", webhook_body
      expect(last_response).to have_status(401)
      expect(last_response.body).to include("invalid hmac")
    end

    it "inserts the subscription object from the received webhook" do
      post "/v1/stripe/webhook", webhook_body
      expect(last_response).to have_status(200)

      expect(Webhookdb::Subscription.all).to have_length(1)
      sub = Webhookdb::Subscription.first
      expect(sub.stripe_id).to eq("sub_JigYoW2aRYfl0R")
      expect(sub.stripe_json["status"]).to eq("active")
    end

    it "updates the subscription object from the received webhook" do
      Webhookdb::Subscription.create(
        stripe_id: "sub_JigYoW2aRYfl0R",
        stripe_json: {
          "status": "paused",
        }.to_json,
      )

      post "/v1/stripe/webhook", webhook_body
      expect(last_response).to have_status(200)

      expect(Webhookdb::Subscription.all).to have_length(1)
      expect(Webhookdb::Subscription.first.stripe_json["status"]).to eq("active")
    end
  end
end
