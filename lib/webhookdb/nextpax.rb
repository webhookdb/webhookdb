# frozen_string_literal: true

require "appydays/configurable"

module Webhookdb::Nextpax
  include Appydays::Configurable

  configurable(:nextpax) do
    setting :http_timeout, 30
    setting :page_size, 20
  end
end
