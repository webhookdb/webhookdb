# frozen_string_literal: true

require "appydays/configurable"

module Webhookdb::Plaid
  include Appydays::Configurable

  configurable(:plaid) do
    setting :page_size, 100
    setting :http_timeout, 30
  end

  # Manual backfilling is not supported on Plaid integrations.
  # If a manual backfill is attempted, direct customer to this url.
  DOCUMENTATION_URL = "https://webhookdb.com/docs/plaid"

  def self.webhook_response(request, webhook_secret)
    # Eventually we can figure out how to verify Plaid webhooks,
    # but it's sort of crazy so ignore it for now.
    return Webhookdb::WebhookResponse.ok(status: 202) if request.env["HTTP_PLAID_VERIFICATION"]
    return Webhookdb::WebhookResponse.for_standard_secret(request, webhook_secret, ok_status: 200)
  end
end
