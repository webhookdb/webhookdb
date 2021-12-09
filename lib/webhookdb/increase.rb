# frozen_string_literal: true

class Webhookdb::Increase
  extend Webhookdb::MethodUtilities
  include Appydays::Loggable

  def self.webhook_response(request, webhook_secret)
    http_signature = request.env["HTTP_X_BANK_WEBHOOK_SIGNATURE"]

    return [401, {"Content-Type" => "application/json"}, '{"message": "missing hmac"}'] if http_signature.nil?

    request.body.rewind
    request_data = request.body.read

    computed_signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), webhook_secret, request_data)

    if http_signature != "sha256=" + computed_signature
      # Invalid signature
      self.logger.warn "increase signature verification error"
      return [401, {"Content-Type" => "application/json"}, '{"message": "invalid hmac"}']
    end

    return [200, {"Content-Type" => "application/json"}, '{"o":"k"}']
  end

  # this helper function finds the relevant object data and helps us avoid repeated code
  def self.find_desired_object_data(body)
    return body.fetch("data", body)
  end

  # this function interprets webhook contents to assist with filtering webhooks by object type in our increase services
  def self.contains_desired_object(webhook_body, desired_object_name)
    object_of_interest = self.find_desired_object_data(webhook_body)
    object_id = object_of_interest["id"]
    return object_id.include?(desired_object_name)
  end
end
