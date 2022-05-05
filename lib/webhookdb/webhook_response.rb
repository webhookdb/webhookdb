# frozen_string_literal: true

require "webhookdb/typed_struct"

class Webhookdb::WebhookResponse < Webhookdb::TypedStruct
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
