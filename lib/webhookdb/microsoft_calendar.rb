# frozen_string_literal: true

require "appydays/configurable"

module Webhookdb::MicrosoftCalendar
  include Appydays::Configurable
  extend Webhookdb::MethodUtilities

  singleton_attr_accessor :calendar_view_start_time
  singleton_attr_accessor :calendar_view_end_time

  configurable(:microsoft_calendar) do
    # How many calendars/events should we fetch in a single page?
    # Higher uses slightly more memory but fewer API calls.
    # Apparent maximum is 999,999,999.
    setting :list_page_size, 500
    # How many rows should we upsert at a time?
    # Higher is fewer upserts, but can create very large SQL strings,
    # which can have negative performance.
    setting :upsert_page_size, 500

    # These should be ISO8601 strings. We use them in our calls to the Microsoft Graph API
    # to determine the timeframe we are pulling events from.
    setting :calendar_view_start, Time.new(2022, 10, 1).iso8601
    setting :calendar_view_end, (Time.new(2022, 10, 1) + 1825.days).iso8601

    setting :http_timeout, 30

    after_configured do
      self.calendar_view_start_time = Time.parse(self.calendar_view_start)
      self.calendar_view_end_time = Time.parse(self.calendar_view_end)
      raise ArgumentError, "calendar view end must be after calendar view start" if
        self.calendar_view_start_time >= self.calendar_view_end_time
    end
  end
end
