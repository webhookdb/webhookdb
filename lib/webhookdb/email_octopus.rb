# frozen_string_literal: true

require "appydays/configurable"

require "webhookdb/crypto"

module Webhookdb::EmailOctopus
  include Appydays::Configurable

  configurable(:email_octopus) do
    setting :http_timeout, 30
    setting :page_size, 100
    setting :cron_expression, "0 */4 * * *"
  end

  def self.verify_webhook(data, hmac_header, webhook_secret)
    calculated_hmac = Webhookdb::Crypto.bin2hex(
      OpenSSL::HMAC.digest("sha256", webhook_secret, data),
    )
    verified = ActiveSupport::SecurityUtils.secure_compare("sha256=#{calculated_hmac}", hmac_header)
    return verified
  end
end
