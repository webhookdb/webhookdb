# frozen_string_literal: true

require "appydays/configurable"

module Webhookdb::Icalendar
  # Manual backfilling is not supported on iCalendar integrations.
  # If a manual backfill is attempted, direct customer to this url.
  DOCUMENTATION_URL = "https://webhookdb.com/docs/icalendar"
end
