# frozen_string_literal: true

require "appydays/configurable"

module Webhookdb::Icalendar
  # Manual backfilling is not supported on iCalendar integrations.
  # If a manual backfill is attempted, direct customer to this url.
  DOCUMENTATION_URL = "https://docs.webhookdb.com/guides/icalendar/"

  EVENT_REPLICATORS = ["icalendar_event_v1", "icalendar_event_v1_partitioned"].freeze

  include Appydays::Configurable

  configurable(:icalendar) do
    # Do not store events older than this when syncing recurring events.
    # Many icalendar feeds are misconfigured and this prevents enumerating 2000+ years of recurrence.
    setting :oldest_recurring_event, "2000-01-01", convert: ->(s) { Date.parse(s) }
    # Calendars feeds are considered 'fresh' if they have been synced this long ago or less.
    # Most services only update every day or so.
    # Assume it takes 5s to sync each feed (request, parse, upsert).
    # If you have 10,000 feeds, that is 50,000 seconds,
    # or almost 14 hours of processing time, or two threads for 7 hours.
    setting :sync_period_hours, 6
    # When stale feeds are scheduled for a resync,
    # 'smear' them along this duration. Using 0 would immediately enqueue syncs of all stale feeds,
    # which could saturate the job server. The number here means that feeds will be refreshed between every
    # +sync_period_hours+ and +sync_period_hours+ + +sync_period_splay_hours+.
    setting :sync_period_splay_hours, 1
    # Number of threads for the 'precheck' threadpool, used when enqueing icalendar sync jobs.
    # Since the precheck process uses many threads, but each check is resource-light and not latency-sensitive,
    # we use a shared threadpool for it.
    setting :precheck_feed_change_pool_size, 12

    # Cancelled events that were last updated this long ago are deleted from the database.
    setting :stale_cancelled_event_threshold_days, 20
    # The stale row deleter job will look for rows this far before the threshold.
    setting :stale_cancelled_event_lookback_days, 3

    # The URL of the icalproxy server, if using one.
    # See https://github.com/webhookdb/icalproxy for more info.
    # Used to get property HTTP semantics for any icalendar feed, like Etag and HEAD requests.
    setting :proxy_url, ""
    # Api key of the icalproxy server, if using one.
    # See https://github.com/webhookdb/icalproxy
    setting :proxy_api_key, ""

    # Because some ical files can be several megabytes, and on all sorts of servers,
    # provide separate connect (also used for write) and read timeouts.
    setting :http_connect_timeout, 30
    setting :http_read_timeout, 30
  end
end
