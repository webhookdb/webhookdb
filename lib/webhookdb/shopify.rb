# frozen_string_literal: true

require "active_support/security_utils"

class Webhookdb::Shopify
  # This function is used in the backfill process to parse out the
  # pagination_token from the responses
  def self.parse_link_header(header)
    parts = header.split(",")

    parts.to_h do |part, _|
      section = part.split(";")
      name = section[1][/rel="(.*)"/, 1].to_sym
      url = section[0][/<(.*)>/, 1]
      # results = section[2][/results="(.*)"/, 1] == 'true'

      [name, url]
    end
  end

  # Compare the computed HMAC digest based on the shared secret and the
  # request contents to the reported HMAC in the headers
  #
  # see https://shopify.dev/tutorials/manage-webhooks#verifying-webhooks
  def self.verify_webhook(data, hmac_header, webhook_secret)
    calculated_hmac = Base64.strict_encode64(OpenSSL::HMAC.digest("sha256", webhook_secret, data))
    return ActiveSupport::SecurityUtils.secure_compare(calculated_hmac, hmac_header)
  end
end
