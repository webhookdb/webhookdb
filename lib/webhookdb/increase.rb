# frozen_string_literal: true

class Webhookdb::Increase
  extend Webhookdb::MethodUtilities
  include Appydays::Loggable

  def self.webhook_response(request, webhook_secret)
    http_signature = request.env["x-bank-webhook-signature"]

    return [401, {"Content-Type" => "application/json"}, '{"message": "missing hmac"}'] if http_signature.nil?

    request.body.rewind
    request_data = request.body.read

    computed_signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), webhook_secret, request_data)

    if http_signature != computed_signature
      # Invalid signature
      self.logger.debug "increase signature verification error"
      return [401, {"Content-Type" => "application/json"}, '{"message": "invalid hmac"}']
    end

    return [200, {"Content-Type" => "application/json"}, '{"o":"k"}']
  end
end
