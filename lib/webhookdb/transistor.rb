# frozen_string_literal: true

require "appydays/configurable"

module Webhookdb::Transistor
  include Appydays::Configurable

  configurable(:transistor) do
    setting :episode_cron_expression, "30 * * * *"
    setting :show_cron_expression, "0 0 */1 * *"
    setting :http_timeout, 30
  end
end
