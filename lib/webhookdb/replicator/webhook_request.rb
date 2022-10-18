# frozen_string_literal: true

class Webhookdb::Replicator::WebhookRequest < Webhookdb::TypedStruct
  attr_accessor :body, :headers, :path, :method
end
