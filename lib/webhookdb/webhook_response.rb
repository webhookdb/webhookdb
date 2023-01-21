# frozen_string_literal: true

require "webhookdb/typed_struct"

class Webhookdb::WebhookResponse < Webhookdb::TypedStruct
  # The standard WebhookDB Secret header, in RFC header format (My-Hdr).
  SECRET_HEADER_RFC = "Whdb-Webhook-Secret"
  # The standard WebhookDB secret header, in Rack header format (HTTP_MY_HDR).
  SECRET_HEADER_RACK = "HTTP_WHDB_WEBHOOK_SECRET"

  # Compare the value of the SECRET_HEADER_RACK in the request header.
  # @param [Rack::Request] request
  # @param [String] webhook_secret
  # @return [Webhookdb::WebhookResponse]
  def self.for_standard_secret(request, webhook_secret, ok_status: 202)
    hdr_secret = request.env[SECRET_HEADER_RACK]
    return self.error("missing secret header") if hdr_secret.nil?
    matches = ActiveSupport::SecurityUtils.secure_compare(webhook_secret, hdr_secret)
    return self.error("secret mismatch") unless matches
    return self.ok(status: ok_status)
  end

  attr_reader :status,
              :headers,
              :body,
              :reason

  def self.error(reason, status: 401)
    return self.new(status:, json: {message: reason}, reason:)
  end

  def self.ok(json: {o: "k"}, status: 202)
    return self.new(status:, json:)
  end

  def initialize(status:, body: nil, json: nil, reason: nil, headers: {})
    raise "Reason must be provided if returning an error" if !reason && status >= 400
    if json
      body = json.to_json
      headers["Content-Type"] = "application/json"
    end
    raise ":body or :json must be provided" if body.nil?
    super(status:, body:, headers:, reason:)
  end

  # @return [Array<Integer, Hash, String>]
  def to_rack
    return [self.status, self.headers, self.body]
  end
end
