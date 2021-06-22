# frozen_string_literal: true


require 'webhookdb/subscription'

RSpec.describe "Webhookdb::Subscription", :db do
  let(:described_class) { Webhookdb::Subscription }

  describe "create_or_update" do
    let(:data) do

          { "id" => "sub_JigYoW2aRYfl0R",
            "object" => "subscription",
            "application_fee_percent" => nil,
            "automatic_tax" =>
            { "enabled" => false
            },
            "billing" => "charge_automatically",
            "billing_cycle_anchor" => 1624389749,
            "billing_thresholds" => nil,
            "cancel_at" => nil,
            "cancel_at_period_end" => false,
            "canceled_at" => nil,
            "collection_method" => "charge_automatically",
            "created" => 1624389749,
            "current_period_end" => 1626981749,
            "current_period_start" => 1624389749,
            "customer" => "cus_JR8V3eF6JmvjKZ",
            "days_until_due" => nil,
            "default_payment_method" => nil,
            "default_source" => nil,
            "default_tax_rates" => [],
            "discount" => nil,
            "ended_at" => nil,
            "invoice_customer_balance_settings" =>
              { "consume_applied_balance_on_void" => true
              },
            "items" =>
              { "object" => "list",
                "data" => [
                { "id" => "si_JigYnp1pfGlMbs",
                  "object" => "subscription_item",
                  "billing_thresholds" => nil,
                  "created" => 1624389749,
                  "metadata" => {

                  },
                  "plan" =>
                  { "id" => "price_1J4s6rFFYxHXGyKx5NqSpSYB",
                    "object" => "plan",
                    "active" => true,
                    "aggregate_usage" => nil,
                    "amount" => 2500,
                    "amount_decimal" => "2500",
                    "billing_scheme" => "per_unit",
                    "created" => 1624301077,
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
                    "usage_type" => "licensed"
                  },
                  "price" =>
                    { "id" => "price_1J4s6rFFYxHXGyKx5NqSpSYB",
                      "object" => "price",
                      "active" => true,
                      "billing_scheme" => "per_unit",
                      "created" => 1624301077,
                      "currency" => "usd",
                      "livemode" => false,
                      "lookup_key" => nil,
                      "metadata" => {

                      },
                      "nickname" => nil,
                      "product" => "prod_JiIi6yyo7A3cha",
                      "recurring" =>
                      { "aggregate_usage" => nil,
                        "interval" => "month",
                        "interval_count" => 1,
                        "trial_period_days" => nil,
                        "usage_type" => "licensed"
                      },
                      "tiers_mode" => nil,
                      "transform_quantity" => nil,
                      "type" => "recurring",
                      "unit_amount" => 2500,
                      "unit_amount_decimal" => "2500"
                    },
                  "quantity" => 1,
                  "subscription" => "sub_JigYoW2aRYfl0R",
                  "tax_rates" => []
                } ],
                "has_more" => false,
                "total_count" => 1,
                "url" => "/v1/subscription_items?subscription=sub_JigYoW2aRYfl0R"
              },
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
              { "id" => "price_1J4s6rFFYxHXGyKx5NqSpSYB",
                "object" => "plan",
                "active" => true,
                "aggregate_usage" => nil,
                "amount" => 2500,
                "amount_decimal" => "2500",
                "billing_scheme" => "per_unit",
                "created" => 1624301077,
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
                "usage_type" => "licensed"
              },
            "quantity" => 1,
            "schedule" => nil,
            "start" => 1624397153,
            "start_date" => 1624389749,
            "status" => "active",
            "tax_percent" => nil,
            "transfer_data" => nil,
            "trial_end" => nil,
            "trial_start" => nil
          }
    end

    it "creates a subscription for a given org if one doesn't exist" do
      Webhookdb::Subscription.create_or_update(data)

      sub = Webhookdb::Subscription[stripe_id: "sub_JigYoW2aRYfl0R"]
      expect(sub).to_not be_nil
    end
    it "updates the subscription status of an existing subscription" do
      Webhookdb::Subscription.create(stripe_id: "sub_JigYoW2aRYfl0R", stripe_json: {})
      Webhookdb::Subscription.create_or_update(data)

      sub = Webhookdb::Subscription[stripe_id: "sub_JigYoW2aRYfl0R"]
      expect(sub).to_not be_nil
      expect(sub.stripe_customer_id).to eq("cus_JR8V3eF6JmvjKZ")
      expect(sub.stripe_json).to have_key("status")
    end
  end

  describe "webhook_response" do
    it "returns a 401 as per spec if there is no Authorization header" do
      req = fake_request
      data = req.body
      status, headers, _body = Webhookdb::Subscription.webhook_response(req)
      expect(status).to eq(401)
    end

    it "returns a 401 for an invalid Authorization header" do
      Webhookdb::Subscription.webhook_secret = "user:pass"
      req = fake_request(input: '{"data": "asdfghujkl"}')
      data = req.body
      req.add_header("HTTP_STRIPE_SIGNATURE",
                     "t=1492774577,v1=5257a869e7ecebeda32affa62cdca3fa51cad7e77a0e56ff536d0ce8e108d8bd",)
      status, _headers, body = Webhookdb::Subscription.webhook_response(req)
      expect(status).to eq(401)
      expect(body).to include("invalid hmac")
    end

    it "returns a 200 with a valid Authorization header" do
      Webhookdb::Subscription.webhook_secret = "user:pass"
      req = fake_request(input: '{"data": "asdfghujkl"}')
      data = req.body
      timestamp = Time.now
      stripe_signature = "t=" + timestamp.to_i.to_s + ",v1=" # this is the interim value
      stripe_signature += Stripe::Webhook::Signature.compute_signature(timestamp, data, Webhookdb::Subscription.webhook_secret)
      req.add_header("HTTP_STRIPE_SIGNATURE", stripe_signature)
      status, _headers, _body = Webhookdb::Subscription.webhook_response(req)
      expect(status).to eq(200)
    end
  end
end
