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

  def self.verify_webhook(data, hmac_header)
    calculated_hmac = "sha1=#{OpenSSL::HMAC.hexdigest('SHA1', self.client_secret, data)}"
    return ActiveSupport::SecurityUtils.secure_compare(calculated_hmac, hmac_header)
  end

  def self.auth_headers(token)
    return {"Intercom-Version" => "2.9", "Authorization" => "Bearer #{token}"}
  end
end
