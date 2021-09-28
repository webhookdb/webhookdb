# frozen_string_literal: true

class Webhookdb::Convertkit
  include Appydays::Configurable

  configurable(:convertkit) do
    setting :sleep_seconds, 1.5
  end
end
