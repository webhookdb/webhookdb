# frozen_string_literal: true

require "appydays/configurable"
require "appydays/loggable"

module Webhookdb::Front
  include Appydays::Configurable

  CHANNEL_EVENT_TYPES = Set.new(["authorization", "delete", "message", "message_autoreply", "message_imported"])

  configurable(:front) do
    setting :http_timeout, 30

    # WebhookDB App: App Secret from Basic Information tab in Front UI.
    setting :app_secret, "front_api_secret", key: ["FRONT_APP_SECRET", "FRONT_API_SECRET"]
    # WebhookDB App: Client ID from OAuth tab in Front UI.
    setting :client_id, "front_client_id"
    # WebhookDB App: Client Secret from OAuth tab in Front UI.
    setting :client_secret, "front_client_secret"

    setting :signalwire_channel_app_id, "front_swchan_app_id"
    setting :signalwire_channel_app_secret, "front_swchan_app_secret"
    setting :signalwire_channel_client_id, "front_swchan_client_id"
    setting :signalwire_channel_client_secret, "front_swchan_client_secret"

    setting :channel_sync_refreshness_cutoff, 48.hours.to_i
  end

  def self.verify_signature(request, secret)
    body = Webhookdb::Http.rewind_request_body(request).read
    base_string = "#{request.env['HTTP_X_FRONT_REQUEST_TIMESTAMP']}:#{body}"
    calculated_signature = OpenSSL::HMAC.base64digest(OpenSSL::Digest.new("sha256"), secret, base_string)
    return calculated_signature == request.env["HTTP_X_FRONT_SIGNATURE"]
  end

  def self.webhook_response(request, secret)
    return Webhookdb::WebhookResponse.error("missing signature") unless request.env["HTTP_X_FRONT_SIGNATURE"]

    from_front = self.verify_signature(request, secret)
    return Webhookdb::WebhookResponse.ok(status: 200) if from_front
    return Webhookdb::WebhookResponse.error("invalid signature")
  end

  def self.initial_verification_request_response(request, secret)
    from_front = self.verify_signature(request, secret)
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

  def self.channel_jwt_jti = SecureRandom.hex(4)
end
