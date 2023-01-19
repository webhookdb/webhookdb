# frozen_string_literal: true

require "appydays/configurable"

module Webhookdb::GoogleCalendar
  include Appydays::Configurable

  configurable(:google_calendar) do
    setting :page_size, 100
  end
end
