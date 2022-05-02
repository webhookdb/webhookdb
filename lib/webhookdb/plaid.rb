# frozen_string_literal: true

require "appydays/configurable"

module Webhookdb::Plaid
  include Appydays::Configurable

  configurable(:plaid) do
    setting :page_size, 100
  end

  def self.webhook_response(request, webhook_secret)
    # Eventually we can figure out how to verify Plaid webhooks,
    # but it's sort of crazy so ignore it for now.
    return [202, {"Content-Type" => "text/plain"}, "ok"] if request.env["HTTP_PLAID_VERIFICATION"]
    # Compare the value of the secret in the header.
    # This is easier than the hash.
    hdr_secret = request.env["HTTP_WHDB_WEBHOOK_SECRET"]
    return [401, {"Content-Type" => "application/json"}, '{"message": "missing secret header"}'] if hdr_secret.nil?
    return [401, {"Content-Type" => "application/json"}, '{"message": "secret mismatch"}'] unless
      ActiveSupport::SecurityUtils.secure_compare(webhook_secret, hdr_secret)
    return [200, {"Content-Type" => "application/json"}, '{"o":"k"}']
  end
end
