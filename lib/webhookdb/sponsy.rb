# frozen_string_literal: true

require "appydays/configurable"

module Webhookdb::Sponsy
  include Appydays::Configurable

  configurable(:sponsy) do
    setting :cron_expression, "*/30 */4 * * * *" # “At every 30th minute past every 4th hour.”
    setting :page_size, 100
  end
end
