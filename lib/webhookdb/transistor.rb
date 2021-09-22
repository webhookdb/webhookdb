# frozen_string_literal: true

class Webhookdb::Transistor
  include Appydays::Configurable

  configurable(:transistor) do
    setting :sleep_seconds, 1.5
  end
end
