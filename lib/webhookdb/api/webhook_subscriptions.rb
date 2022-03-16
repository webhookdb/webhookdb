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
        membership = customer.verified_memberships_dataset[organization: org]
        merror!(403, "You don't have permissions with that organization.") if membership.nil?
        return sint
      end
    end

    before_validation do
      # Our CLI will submit both of these params no matter what--in order to avoid triggering the 'mutually exclusive'
      # param error, we need to delete the param that shows up as an empty string
      params.delete(:org_identifier) if params[:org_identifier] == ""
      params.delete(:service_integration_opaque_id) if params[:service_integration_opaque_id] == ""
    end

    params do
      requires :url, prompt: "Enter the URL that WebhookDB should POST webhooks to:"
      requires :webhook_secret, prompt: "Enter a random secret used to sign and verify webhooks to the given url:"
      optional :org_identifier, type: String, allow_blank: false
      optional :service_integration_opaque_id, type: String, allow_blank: false
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
          (webhook_sub = Webhookdb::WebhookSubscription[opaque_id: params[:opaque_id]]) or forbidden!
          webhook_sub
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
      end
    end
  end
end
