# frozen_string_literal: true

require "appydays/configurable"

module Webhookdb::Plaid
  include Appydays::Configurable

  configurable(:plaid) do
    setting :page_size, 100
    setting :sync_timeout, 10
  end

  def self.webhook_response(request, webhook_secret)
    # Eventually we can figure out how to verify Plaid webhooks,
    # but it's sort of crazy so ignore it for now.
    return Webhookdb::WebhookResponse.ok(status: 202) if request.env["HTTP_PLAID_VERIFICATION"]
    # Compare the value of the secret in the header.
    # This is easier than the hash.
    hdr_secret = request.env["HTTP_WHDB_WEBHOOK_SECRET"]
    return Webhookdb::WebhookResponse.error("missing secret header") if hdr_secret.nil?
    return Webhookdb::WebhookResponse.error("secret mismatch") unless
      ActiveSupport::SecurityUtils.secure_compare(webhook_secret, hdr_secret)
    return Webhookdb::WebhookResponse.ok(status: 200)
  end
end
