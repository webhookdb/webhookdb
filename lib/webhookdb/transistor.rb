# frozen_string_literal: true

require "appydays/configurable"

module Webhookdb::Transistor
  include Appydays::Configurable

  configurable(:transistor) do
    setting :http_timeout, 30
  end
end
