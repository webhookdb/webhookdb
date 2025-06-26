# frozen_string_literal: true

require "appydays/configurable"

module Webhookdb::Intercom
  include Appydays::Configurable

  configurable(:intercom) do
    setting :client_id, "whdb_intercom_client_id", key: "INTERCOM_CLIENT_ID"
    setting :client_secret, "whdb_intercom_client_secret", key: "INTERCOM_CLIENT_SECRET"
    setting :http_timeout, 30
    setting :page_size, 20
  end

  def self.webhook_response(request, webhook_secret)
    header_value = request.env["HTTP_X_HUB_SIGNATURE"]
    return Webhookdb::WebhookResponse.error("missing hmac") if header_value.nil?
    request_data = Webhookdb::Http.rewind_request_body(request).read
    hmac = OpenSSL::HMAC.hexdigest("SHA1", webhook_secret, request_data)
    calculated_hmac = "sha1=#{hmac}"
    verified = ActiveSupport::SecurityUtils.secure_compare(calculated_hmac, header_value)
    return Webhookdb::WebhookResponse.ok if verified
    return Webhookdb::WebhookResponse.error("invalid hmac")
  end

  def self.auth_headers(token)
    return {"Intercom-Version" => "2.9", "Authorization" => "Bearer #{token}"}
  end
end
