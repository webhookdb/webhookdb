# frozen_string_literal: true

class Webhookdb::Stripe
  extend Webhookdb::MethodUtilities
  include Appydays::Configurable
  include Appydays::Loggable

  configurable(:stripe) do
    setting :api_key, "lithic_stripe_api_key", key: "STRIPE_API_KEY"
    setting :webhook_secret, "lithic_stripe_webhook_secret", key: "STRIPE_WEBHOOK_SECRET"

    after_configured do
      ::Stripe.api_key = self.api_key
    end
  end

  def self.webhook_response(request, webhook_secret)
    auth = request.env["HTTP_STRIPE_SIGNATURE"]

    return Webhookdb::WebhookResponse.error("missing hmac") if auth.nil?

    request.body.rewind
    request_data = request.body.read

    begin
      Stripe::Webhook.construct_event(
        request_data, auth, webhook_secret,
      )
    rescue Stripe::SignatureVerificationError => e
      self.logger.error "stripe signature verification error: ", e
      return Webhookdb::WebhookResponse.error("invalid hmac")
    end

    return Webhookdb::WebhookResponse.ok
  end
end
