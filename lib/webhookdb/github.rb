# frozen_string_literal: true

require "active_support/security_utils"

class Webhookdb::Github
  include Appydays::Configurable

  configurable(:github) do
    setting :http_timeout, 30
    setting :activity_cron_expression, "*/5 * * * *"
  end

  def self.parse_link_header(header)
    return Webhookdb::Shopify.parse_link_header(header)
  end

  # see https://docs.github.com/en/webhooks/using-webhooks/validating-webhook-deliveries
  def self.verify_webhook(body, hmac_header, webhook_secret)
    calculated_hash = "sha256=" + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), webhook_secret, body)
    return ActiveSupport::SecurityUtils.secure_compare(calculated_hash, hmac_header)
  end
end
