# frozen_string_literal: true

require "appydays/configurable"

module Webhookdb::Icalendar
  # Manual backfilling is not supported on iCalendar integrations.
  # If a manual backfill is attempted, direct customer to this url.
  DOCUMENTATION_URL = "https://docs.webhookdb.com/guides/icalendar/"

  include Appydays::Configurable

  configurable(:icalendar) do
    # Do not store events older then this when syncing recurring events.
    # Many icalendar feeds are misconfigured and this prevents enumerating 2000+ years of recurrence.
    setting :oldest_recurring_event, "1990-01-01", convert: ->(s) { Date.parse(s) }
  end
end
