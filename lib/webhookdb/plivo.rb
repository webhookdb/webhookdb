# frozen_string_literal: true

require "appydays/configurable"
require "appydays/loggable"

module Webhookdb::Plivo
  include Appydays::Configurable
  include Appydays::Loggable

  configurable(:plivo) do
    setting :http_timeout, 25
  end

  def self.request(method, tail, auth_id:, auth_token:, body: nil, **options)
    tail = tail.delete_suffix("/")
    url = "https://api.plivo.com/v1/Account/#{auth_id}#{tail}/"
    options[:basic_auth] = {username: auth_id, password: auth_token}
    options[:logger] = self.logger
    if body
      options[:headers] = {"Content-Type" => "application/json"}
      options[:body] = body.to_json
    end
    options[:method] = method if method != :get
    return Webhookdb::Http.send(method, url, **options)
  end

  def self.webhook_response(request, auth_token)
    raise Webhookdb::InvalidPrecondition, "auth_token cannot be nil/blank" if auth_token.blank?
    # See https://www.plivo.com/docs/sms/xml/request#validation
    # See https://www.plivo.com/docs/sms/concepts/signature-validation#code
    (signature = request.env["HTTP_X_PLIVO_SIGNATURE_V2"]) or
      return Webhookdb::WebhookResponse.error("missing signature")
    (nonce = request.env["HTTP_X_PLIVO_SIGNATURE_V2_NONCE"]) or
      return Webhookdb::WebhookResponse.error("missing nonce")
    url = request.url
    uri = url.split("?")[0]
    ok = self._valid_signature?(uri, nonce, signature, auth_token)
    return ok ? Webhookdb::WebhookResponse.ok : Webhookdb::WebhookResponse.error("invalid signature")
  end

  # Copied from https://github.com/plivo/plivo-ruby/blob/119038345475c6216bf040926747105b66fd588a/lib/plivo/utils.rb#L213C1-L220C8
  # We do not use the Plivo gem since it is a mess.
  def self._valid_signature?(uri, nonce, signature, auth_token)
    parsed_uri = URI.parse(uri)
    uri_details = {host: parsed_uri.host, path: parsed_uri.path}
    uri_builder_module = parsed_uri.scheme == "https" ? URI::HTTPS : URI::HTTP
    data_to_sign = uri_builder_module.build(uri_details).to_s + nonce
    sha256_digest = OpenSSL::Digest.new("sha256")
    encoded_digest = Base64.encode64(OpenSSL::HMAC.digest(sha256_digest, auth_token, data_to_sign)).strip
    return ActiveSupport::SecurityUtils.secure_compare(encoded_digest, signature)
  end
end
