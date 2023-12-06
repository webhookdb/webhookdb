# frozen_string_literal: true

require "appydays/configurable"
require "appydays/loggable"

module Webhookdb::Signalwire
  include Appydays::Configurable
  include Appydays::Loggable

  configurable(:signalwire) do
    setting :http_timeout, 30
  end
end
