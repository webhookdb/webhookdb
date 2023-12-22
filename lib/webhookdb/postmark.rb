# frozen_string_literal: true

require "appydays/configurable"

module Webhookdb::Postmark
  include Appydays::Configurable

  configurable(:postmark) do
    # See https://postmarkapp.com/support/article/800-ips-for-firewalls#webhooks
    setting :allowed_ips,
            ["127.0.0.1", "3.134.147.250", "50.31.156.6", "50.31.156.77", "18.217.206.57"],
            convert: ->(s) { s.split.map(&:strip) }
  end

  def self.webhook_response(request)
    ip = request.ip
    allowed = self.allowed_ips.include?(ip)
    return allowed ? Webhookdb::WebhookResponse.ok : Webhookdb::WebhookResponse.error("invalid ip")
  end
end
