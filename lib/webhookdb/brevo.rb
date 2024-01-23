# frozen_string_literal: true

# API Reference: https://developers.brevo.com/reference/getemaileventreport-1
# Webhook is supported: https://developers.brevo.com/docs/how-to-use-webhooks
class Webhookdb::Brevo
  extend Webhookdb::MethodUtilities
  include Appydays::Configurable
  include Appydays::Loggable

  configurable(:brevo) do
    setting :http_timeout, 30
  end

  # @todo
  def self.webhook_response(request)

    x_sib_server = request.headers.fetch(:x-sib-server, nil)
    if x_sib_server.nil? || !x_sib_server['BREVO']
      self.logger.warn "Brevo webhook invalid response: x_sib_server header = #{x_sib_server}"
      return Webhookdb::WebhookResponse.error("invalid response")
    end

    return Webhookdb::WebhookResponse.ok
  end
end
