# frozen_string_literal: true

require "appydays/configurable"
require "appydays/loggable"

module Webhookdb::Twilio
  include Appydays::Configurable
  include Appydays::Loggable

  configurable(:twilio) do
    setting :http_timeout, 30
  end
end
