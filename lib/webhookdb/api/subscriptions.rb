# frozen_string_literal: true

require "grape"

require "webhookdb/api"
require "webhookdb/admin_api"

class Webhookdb::API::Subscriptions < Webhookdb::API::V1
  resource :organizations do
    route_param :org_identifier, type: String do
      resource :subscriptions do
        desc "Provides the user with subscription information for the organization"
        get do
          org = lookup_org!
          status = Webhookdb::Subscription.status_for_org(org)
          status 200
          present status.as_json
        end

        desc "Authenticates stripe user and returns stripe checkout session or billing portal url"
        params do
          optional :plan, type: String
          optional :guard_confirm
        end
        post :open_portal do
          org = lookup_org!
          merror!(409, "This organization is not registered with Stripe.") if org.stripe_customer_id.blank?
          subscription = Webhookdb::Subscription[stripe_customer_id: org.stripe_customer_id]
          if subscription
            if params[:plan] && !params.key?(:guard_confirm)
              Webhookdb::API::Helpers.prompt_for_required_param!(
                request,
                :guard_confirm,
                "WARNING: You already have a subscription, but have specified a plan. " \
                "You will be brought to your subscription so you can modify or cancel it. " \
                "Press Enter to continue:",
              )
            end
            session_url = org.get_stripe_billing_portal_url
          else
            plans = Webhookdb::Subscription.list_plans
            real_plan = plans.find { |p| p.key == params[:plan] }
            unless real_plan
              Webhookdb::API::Helpers.prompt_for_required_param!(
                request,
                :plan,
                "Enter the plan you want to subscribe to (#{plans.map(&:key).join(', ')}):",
              )
            end
            session_url = org.get_stripe_checkout_url(real_plan.stripe_price_id)
          end
          data = {url: session_url}
          status 200
          present data
        end

        desc "Returns information about subscription plans"
        get :plans do
          plans = Webhookdb::Subscription.list_plans
          message = "Use `webhookdb subscription edit` to set up or modify your subscription."
          status 200
          present_collection plans, with: Webhookdb::API::SubscriptionPlanEntity, message:
        end
      end
    end
  end
end
