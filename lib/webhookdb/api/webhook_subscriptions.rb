# frozen_string_literal: true

require "webhookdb/api"

class Webhookdb::API::WebhookSubscriptions < Webhookdb::API::V1
  resource :webhook_subscriptions do
    helpers do
      def lookup_sint!
        # verify service integration existence
        sint = Webhookdb::ServiceIntegration[opaque_id: params[:service_integration_opaque_id]]
        merror!(400, "There is no integration with that id.") if sint.nil? || sint.soft_deleted?
        org = sint.organization

        # verify permissions
        customer = current_customer
        membership = customer.memberships_dataset[organization: org, verified: true]
        merror!(403, "You don't have permissions with that organization.") if membership.nil?
        return sint
      end
    end

    params do
      requires :webhook_secret, prompt: "Enter a random secret used to sign and verify webhooks to the given url:"
      requires :url, prompt: "Enter the URL that WebhookDB should POST webhooks to:"
      optional :org_identifier
      optional :service_integration_opaque_id
      exactly_one_of :org_identifier, :service_integration_opaque_id
      mutually_exclusive :org_identifier, :service_integration_opaque_id
    end
    post :create do
      org = params[:org_identifier].nil? ? nil : lookup_org!
      sint = params[:service_integration_opaque_id].nil? ? nil : lookup_sint!
      webhook_sub = Webhookdb::WebhookSubscription.create(
        webhook_secret: params[:webhook_secret],
        deliver_to_url: params[:url],
        organization: org,
        service_integration: sint,
        opaque_id: SecureRandom.hex(6),
      )
      status 200
      present webhook_sub, with: Webhookdb::API::WebhookSubscriptionEntity
    end

    route_param :opaque_id, type: String do
      helpers do
        def lookup_sub!
          (webhook_sub = Webhookdb::WebhookSubscription[opaque_id: params[:opaque_id]]) or forbidden!
          webhook_sub
        end
      end

      post :test do
        webhook_sub = lookup_sub!
        webhook_sub.publish_immediate("test")
        status 200
        present({o: "k"})
      end

      post :delete do
        webhook_sub = lookup_sub!
        webhook_sub.delete
        status 200
        present({o: "k"})
      end
    end
  end
end
