# frozen_string_literal: true

require "appydays/configurable"
require "appydays/loggable"

module Webhookdb::Front
  include Appydays::Configurable

  configurable(:front) do
    # The api secret is used for webhook verification, the client id and secret are used for OAuth
    setting :api_secret, "front_api_secret"
    setting :client_id, "front_client_id"
    setting :client_secret, "front_client_secret"
    setting :http_timeout, 30
  end

  def self.oauth_callback_url = Webhookdb.api_url + "/v1/install/front/callback"

  def self.verify_signature(request)
    request.body.rewind
    body = request.body.read
    base_string = "#{request.env['HTTP_X_FRONT_REQUEST_TIMESTAMP']}:#{body}"
    calculated_signature = OpenSSL::HMAC.base64digest(OpenSSL::Digest.new("sha256"), self.api_secret, base_string)
    return calculated_signature == request.env["HTTP_X_FRONT_SIGNATURE"]
  end

  def self.webhook_response(request)
    return Webhookdb::WebhookResponse.error("missing signature") unless request.env["HTTP_X_FRONT_SIGNATURE"]

    from_front = Webhookdb::Front.verify_signature(request)
    return Webhookdb::WebhookResponse.ok(status: 200) if from_front
    return Webhookdb::WebhookResponse.error("invalid signature")
  end

  def self.initial_verification_request_response(request)
    from_front = self.verify_signature(request)
    if from_front
      return Webhookdb::WebhookResponse.ok(
        json: {challenge: request.env["HTTP_X_FRONT_CHALLENGE"]},
        status: 200,
      )
    end
    return Webhookdb::WebhookResponse.error("invalid credentials")
  end

  def self.auth_headers(token)
    return {"Authorization" => "Bearer #{token}"}
  end
end
