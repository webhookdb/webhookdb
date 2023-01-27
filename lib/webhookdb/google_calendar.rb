# frozen_string_literal: true

require "appydays/configurable"

module Webhookdb::GoogleCalendar
  include Appydays::Configurable

  configurable(:google_calendar) do
    setting :page_size, 100
    setting :watch_ttl, 604_800  # Google's default. Set shorter when testing.
  end
end
