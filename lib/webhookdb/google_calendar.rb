# frozen_string_literal: true

require "appydays/configurable"

module Webhookdb::GoogleCalendar
  include Appydays::Configurable

  configurable(:google_calendar) do
    # How many calendars/events should we fetch in a single page?
    # Higher uses slightly more memory but fewer API calls.
    # Max of 2500.
    setting :list_page_size, 2000
    # How many rows should we upsert at a time?
    # Higher is fewer upserts, but can create very large SQL strings,
    # which can have negative performance.
    setting :upsert_page_size, 500
    # How long should watch channels live.
    # Generally use Google's default (one week),
    # but set shorter when testing.
    setting :watch_ttl, 604_800
    setting :http_timeout, 30
  end

  # Manual backfilling is not supported on Google Calendar integrations.
  # If a manual backfill is attempted, direct customer to this url.
  DOCUMENTATION_URL = "https://docs.webhookdb.com/guides/google-calendar/"

  PUSH_NOT_SUPPORTED_SENTINEL_WATCH_ID = "ech-push-not-supported-for-requested-resource"
end
