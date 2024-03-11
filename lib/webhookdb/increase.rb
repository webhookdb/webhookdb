# frozen_string_literal: true

class Webhookdb::Increase
  extend Webhookdb::MethodUtilities
  include Appydays::Configurable
  include Appydays::Loggable

  configurable(:increase) do
    # This is created in your 'platform' account, and is needed to call the OAuth endpoints.
    # https://dashboard.increase.com/developers/api_keys
    setting :api_key, "increase_api_key"
    # This is created in your Platform account, and is used to sign webhooks,
    # which we get for both platform events (which are ignored) and associated oauth app events
    # (with an Increase-Group-Id header).
    # https://dashboard.increase.com/developers/webhooks
    setting :webhook_secret, "increase_webhook_secret"

    # Id and secret for the WebhookDB Oauth app.
    # https://dashboard.increase.com/developers/oauths
    setting :oauth_client_id, "increase_oauth_fake_client"
    setting :oauth_client_secret, "increase_oauth_fake_secret"

    setting :http_timeout, 30
  end

  class WebhookSignature < Webhookdb::TypedStruct
    attr_accessor :t, :v1

    def _defaults = {t: nil, v1: []}

    def format
      parts = []
      parts << "t=#{self.t.utc.iso8601}" if self.t
      self.v1&.each { |v1| parts << "v1=#{v1}" }
      return parts.join(",")
    end
  end

  # @param s [String,nil]
  # @return [WebhookSignature]
  def self.parse_signature(s)
    sig = WebhookSignature.new
    s&.split(",")&.each do |part|
      key, val = part.split("=")
      if key == "t"
        begin
          sig.t = Time.rfc3339(val)
        rescue ArgumentError
          nil
        end
      elsif key == "v1"
        sig.v1 << val
      end
    end
    return sig
  end

  # @param secret [String]
  # @param data [String]
  # @param t [Time]
  # @return [WebhookSignature]
  def self.compute_signature(secret:, data:, t:)
    signed_payload = "#{t.utc.iso8601}.#{data}"
    sig = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), secret, signed_payload)
    return WebhookSignature.new(v1: [sig], t:)
  end

  OLD_CUTOFF = 35.days
  NEW_CUTOFF = 4.days

  def self.webhook_response(request, webhook_secret, now: Time.now)
    http_signature = request.env["HTTP_INCREASE_WEBHOOK_SIGNATURE"]
    return Webhookdb::WebhookResponse.error("missing header") if http_signature.nil?

    request.body.rewind
    request_data = request.body.read

    parsed_signature = self.parse_signature(http_signature)
    return Webhookdb::WebhookResponse.error("missing timestamp") if parsed_signature.t.nil?
    return Webhookdb::WebhookResponse.error("missing signatures") if parsed_signature.v1.empty?
    return Webhookdb::WebhookResponse.error("too old") if parsed_signature.t < (now - OLD_CUTOFF)
    return Webhookdb::WebhookResponse.error("too new") if parsed_signature.t > (now + NEW_CUTOFF)

    computed_signature = self.compute_signature(secret: webhook_secret, data: request_data, t: parsed_signature.t)
    return Webhookdb::WebhookResponse.error("invalid signature") unless
      parsed_signature.v1.include?(computed_signature.v1.first)

    return Webhookdb::WebhookResponse.ok
  end
end
