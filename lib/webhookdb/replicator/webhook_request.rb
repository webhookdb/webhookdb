# frozen_string_literal: true

class Webhookdb::Replicator::WebhookRequest < Webhookdb::TypedStruct
  attr_accessor :body, :headers, :path, :method
  # @!attribute rack_request
  # When a webhook is processed synchronously, this will be set to the Rack::Request.
  # Normal (async) webhook processing does not have this available.
  attr_accessor :rack_request

  JSON_KEYS = ["body", "headers", "path", "method"].freeze
  def as_json
    return JSON_KEYS.each_with_object({}) do |k, h|
      v = self.send(k)
      h[k] = v.as_json unless v.nil?
    end
  end
end
