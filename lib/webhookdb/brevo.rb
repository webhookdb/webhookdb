# frozen_string_literal: true

# Developer Reference: https://developers.brevo.com/reference
# Webhooks are supported but not in all: https://developers.brevo.com/docs/how-to-use-webhooks
class Webhookdb::Brevo
  extend Webhookdb::MethodUtilities
  include Appydays::Configurable
  include Appydays::Loggable

  configurable(:brevo) do
    setting :http_timeout, 30
    # See https://developers.brevo.com/docs/how-to-use-webhooks#securing-your-webhooks
    # for the originating IPs.
    setting :allowed_ip_blocks, %w[185.107.232.1/24 1.179.112.1/20],
            convert: ->(s) { s.split.map(&:strip) }
  end

  # Verify webhook request via IP origin.
  # (Note: "x-sib-server" header is from backfill API response, not from webhook request.)
  def self.webhook_response(request)
    ip = request.ip
    allowed = self.allowed_ip_blocks.any?{ |block|
    IPAddr.new(block, Socket::AF_INET) === IPAddr.new(ip, Socket::AF_INET) }
    # $stderr.puts ">>>>> Brevo webhook_response: ip = #{ip}, allowed = #{allowed} (Transactional Email Activity)"
    return allowed ? Webhookdb::WebhookResponse.ok : Webhookdb::WebhookResponse.error("invalid ip origin")
  end
end
