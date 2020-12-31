# frozen_string_literal: true

require "appydays/loggable"
require "postmark"

module Webhookdb::Processor
  include Appydays::Loggable

  def self.process(_service_integration, headers:, body:)
    return true
  end
end
