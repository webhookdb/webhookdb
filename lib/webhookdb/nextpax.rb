# frozen_string_literal: true

require "appydays/configurable"

module Webhookdb::Nextpax
  include Appydays::Configurable

  configurable(:nextpax) do
    setting :constants_sync_cron_expression, "0 */12 * * *"
    setting :property_changes_cron_expression, "*/1 * * * *"
    setting :http_timeout, 30
    setting :page_size, 20
  end
end
