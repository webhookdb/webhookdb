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
          status 200
          present Webhookdb::Subscription.status_for_org(org)
        end

        resource :open_portal do
          desc "Authenticates stripe user and returns stripe checkout session or billing portal url"
          post do
            org = lookup_org!
            merror!(409, "This organization is not registered with Stripe.") if org.stripe_customer_id.blank?
            subscription = Webhookdb::Subscription[stripe_customer_id: org.stripe_customer_id]
            session_url = if subscription.present?
                            org.get_stripe_billing_portal_url
            else
              org.get_stripe_checkout_url
                          end
            data = {url: session_url}
            status 200
            present data
          end
        end
      end
    end
  end

  resource :subscriptions do
    resource :portal_return do
      desc "provides a landing page for after the stripe billing page"
      get do
        rendered = render_liquid("pages/billing_callback.liquid")
        status 200
        body rendered
      end
    end

    resource :checkout_cancel do
      desc "provides a landing page for after cancelling the stripe checkout process"
      get do
        rendered = render_liquid("pages/checkout_success.liquid")
        status 200
        body rendered
      end
    end

    resource :checkout_success do
      desc "provides a landing page for after the stripe checkout process"
      get do
        rendered = render_liquid("pages/checkout_success.liquid")
        status 200
        body rendered
      end
    end
  end
end
