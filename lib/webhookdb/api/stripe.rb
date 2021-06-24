# frozen_string_literal: true

require "webhookdb/stripe"
require "webhookdb/api"

class Webhookdb::API::Stripe < Webhookdb::API::V1
  resource :stripe do
    resource :webhook do
      post do
        s_status, s_headers, s_body = Webhookdb::Stripe.webhook_response(request, Webhookdb::Stripe.webhook_secret)

        if s_status < 400 && (request.params["data"]["object"]["object"] == "subscription")
          Webhookdb::Subscription.create_or_update_from_webhook(request.params)
            # TODO: specific behavior if subscription lapses
          end

        s_headers.each { |k, v| header k, v }
        body s_body
        status s_status
      end
    end
  end
end
