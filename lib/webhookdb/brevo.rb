# frozen_string_literal: true

# Developer Reference: https://developers.brevo.com/reference
# Webhooks are supported but not in all: https://developers.brevo.com/docs/how-to-use-webhooks
class Webhookdb::Brevo
  extend Webhookdb::MethodUtilities
  include Appydays::Configurable
  include Appydays::Loggable

  configurable(:brevo) do
    setting :http_timeout, 30
  end

  # @todo
  # Verify webhook request via IP origin.
  # "x-sib-server" header is from backfill API response, not from webhook request.
  def self.webhook_response(request)

    x_sib_server = request.headers.fetch("x-sib-server", nil)
    if x_sib_server.nil? || !x_sib_server[BREVO_HEADER_PREFIX]
      self.logger.warn "Brevo webhook invalid response: x_sib_server header = #{x_sib_server}"
      return Webhookdb::WebhookResponse.error("invalid response")
    end

    return Webhookdb::WebhookResponse.ok
  end
end
