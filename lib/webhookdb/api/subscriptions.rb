# frozen_string_literal: true

require "grape"

require "webhookdb/api"
require "webhookdb/admin_api"

class Webhookdb::API::Subscriptions < Webhookdb::API::V1
  resource :organizations do
    route_param :identifier, type: String do
      resource :subscriptions do
        desc "Provides the user with subscription information for the organization"
        get do
          org = lookup_org!
          status 200
          present Webhookdb::Subscription.status_for_org(org)
        end

        resource :open_portal do
          desc "Authenticates stripe user and returns stripe session url"
          post do
            org = lookup_org!
            begin
              session_url = org.get_stripe_billing_portal_url
            rescue Webhookdb::InvalidPrecondition
              merror!(409, "This organization is not registered with Stripe.")
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
  end
end
