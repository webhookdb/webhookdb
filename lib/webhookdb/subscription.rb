# frozen_string_literal: true

class Webhookdb::Subscription
  extend Webhookdb::MethodUtilities
  include Appydays::Configurable
  include Appydays::Loggable
    #  this class contains helpers for dealing with stripe subscription webhooks

  configurable(:subscription) do
    setting :api_key, "", key: "STRIPE_API_KEY"
    setting :webhook_secret, "", key: "STRIPE_WEBHOOK_SECRET"
  end

  def self.webhook_response(request)
    # info for debugging
    auth = request.env["HTTP_STRIPE_SIGNATURE"]
    log_params = {auth: auth, stripe_body: request.params}
    self.logger.debug "webhook hit stripe subscription endpoint", log_params

    return [401, {"Content-Type" => "application/json"}, '{"message": "missing hmac"}'] if auth.nil?

    request.body.rewind
    request_data = request.body.read

    begin
      Stripe::Webhook.construct_event(
        request_data, auth, self.webhook_secret,
        )
    rescue Stripe::SignatureVerificationError => e
      # Invalid signature
      self.logger.debug "stripe signature verification error: ", e
      return [401, {"Content-Type" => "application/json"}, '{"message": "invalid hmac"}']
    end

    return [200, {"Content-Type" => "application/json"}, '{"o":"k"}']
  end

  # TODO:
  # add helper for validating auth headers
  # add helper for taking json and finding the corresponding org
  #
end
