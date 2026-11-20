# frozen_string_literal: true

require "webhookdb/api"

class Webhookdb::API::WebhookSubscriptions < Webhookdb::API::V1
  include Webhookdb::Service::Types

  resource :organizations do
    route_param :org_identifier, type: String do
      resource :webhook_subscriptions do
        desc "Return all notifications for the given org and its integrations."
        get do
          org = lookup_org!
          subs = org.all_webhook_subscriptions
          message = ""
          if subs.empty?
            message = "Organization #{org.name} has no webhook subscriptions set up.\n" \
                      "Use `webhookdb notifications create` to set one up."
          end
          status 200
          present_collection subs, with: Webhookdb::API::WebhookSubscriptionEntity, message:
        end

        params do
          optional :service_integration_identifier,
                   type: TrimmedString,
                   desc: "If provided, attach the webhook subscription to this integration rather than the org.",
                   prompt: "Which integration is this for? Use the service name, table name, or opaque id.\n" \
                           "See your integrations with `webhookdb integrations list`:"
          optional :url, prompt: "Enter the URL that WebhookDB should POST notifications to:"
          optional :webhook_secret,
                   prompt: "Enter a random secret used to sign and verify notifications to the given url:"
        end
        post :create do
          org = lookup_org!
          sint = lookup_service_integration!(org, params[:service_integration_identifier])
          url = params[:url]
          webhook_sub = Webhookdb::WebhookSubscription.create(
            webhook_secret: params[:webhook_secret],
            deliver_to_url: url,
            service_integration: sint,
            created_by: current_customer,
          )
          message = "All notifications for this #{sint.service_name} integration will be sent to #{url}"
          status 200
          present webhook_sub, with: Webhookdb::API::WebhookSubscriptionEntity, message:
        end

        route_param :opaque_id, type: String do
          helpers do
            def lookup_sub!
              org = lookup_org!
              whsub = org.all_webhook_subscriptions_dataset[opaque_id: params[:opaque_id]]
              merror!(403, "No webhook subscription with that ID exists in that organization.") if whsub.nil?
              set_request_tags(webhook_subscription_id: whsub.id)
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

  resource :webhook_subscriptions do
    post :create do
      endpoint_removed!
    end
    route_param :arg do
      post :test do
        endpoint_removed!
      end
      post :delete do
        endpoint_removed!
      end
    end
  end
end
