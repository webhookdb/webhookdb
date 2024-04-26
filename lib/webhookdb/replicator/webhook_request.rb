# frozen_string_literal: true

class Webhookdb::Replicator::WebhookRequest < Webhookdb::TypedStruct
  attr_accessor :body, :headers, :path, :method
  # @!attribute rack_request
  # When a webhook is processed synchronously, this will be set to the Rack::Request.
  # Normal (async) webhook processing does not have this available.
  attr_accessor :rack_request
end
