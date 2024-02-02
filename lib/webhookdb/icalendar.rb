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
    # Sync icalendar calendars only this often.
    # Most services only update every day or so. Assume it takes 5s to sync each feed (request, parse, upsert).
    # If you have 10,000 feeds, that is 50,000 seconds, or almost 14 hours of processing time,
    # or two threads for 7 hours. The resyncs are spread out across the sync period
    # (ie, no thundering herd every 8 hours), but it is still a good idea to sync as infrequently as possible.
    setting :sync_period_hours, 6
  end
end
