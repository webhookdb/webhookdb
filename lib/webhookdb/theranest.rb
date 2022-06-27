# frozen_string_literal: true

require "appydays/configurable"

module Webhookdb::Theranest
  include Appydays::Configurable

  configurable(:theranest) do
    setting :cron_expression, "0 30 8 * * *" # default to midnight
    setting :page_size, 50
  end
end
