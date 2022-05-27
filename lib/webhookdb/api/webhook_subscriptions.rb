# frozen_string_literal: true

require "webhookdb/api"

class Webhookdb::API::WebhookSubscriptions < Webhookdb::API::V1
  resource :organizations do
    route_param :org_identifier, type: String do
      resource :webhook_subscriptions do
        desc "Return all webhook subscriptions for the given org, and all integrations."
        get do
          org = lookup_org!
          subs = org.all_webhook_subscriptions
          message = ""
          if subs.empty?
            message = "Organization #{org.name} has no webhook subscriptions set up.\n" \
                      "Use `webhookdb webhooks create` to set one up."
          end
          status 200
          present_collection subs, with: Webhookdb::API::WebhookSubscriptionEntity, message:
        end

        params do
          requires :url, prompt: "Enter the URL that WebhookDB should POST webhooks to:"
          requires :webhook_secret, prompt: "Enter a random secret used to sign and verify webhooks to the given url:"
          optional :service_integration_opaque_id,
                   type: String,
                   desc: "If provided, attach the webhook subscription to this integration rather than the org."
        end
        post :create do
          org = lookup_org!
          sint = nil
          if (sintid = params[:service_integration_opaque_id]).present?
            sint = lookup_service_integration!(org, sintid)
          end
          webhook_sub = Webhookdb::WebhookSubscription.create(
            webhook_secret: params[:webhook_secret],
            deliver_to_url: params[:url],
            organization: sint ? nil : org,
            service_integration: sint,
            created_by: current_customer,
          )
          message = if sint
                      "All webhooks for this #{sint.service_name} integration will be sent to #{params[:url]}"
          else
            "All webhooks for all integrations belonging to organization #{org.name} will be sent to #{params[:url]}."
          end
          status 200
          present webhook_sub, with: Webhookdb::API::WebhookSubscriptionEntity, message:
        end

        route_param :opaque_id, type: String do
          helpers do
            def lookup_sub!
              org = lookup_org!
              whsub = org.all_webhook_subscriptions_dataset[opaque_id: params[:opaque_id]]
              merror!(403, "No webhook subscription with that ID exists in that organization.") if whsub.nil?
              return whsub
            end
          end

          post :test do
            webhook_sub = lookup_sub!
            webhook_sub.publish_immediate("test", webhook_sub.id)
            message = "A test event has been sent to #{webhook_sub.deliver_to_url}."
            status 200
            present({}, with: Webhookdb::API::BaseEntity, message:)
          end

          post :delete do
            webhook_sub = lookup_sub!
            webhook_sub.delete
            message = "Events will no longer be sent to #{webhook_sub.deliver_to_url}."
            status 200
            present({}, with: Webhookdb::API::BaseEntity, message:)
          end
        end
      end
    end
  end
end
