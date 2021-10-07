# frozen_string_literal: true

class Webhookdb::Convertkit
  include Appydays::Configurable

  configurable(:convertkit) do
    setting :sleep_seconds, 1.5
  end

  FIND_API_SECRET_HELP = %(- Go to https://app.convertkit.com/account_settings/advanced_settings,
- or from your ConvertKit Dashboard, go to your Advanced Account settings.
- Under the API Header you will see your API Secret, just under your API Key.
- Copy the API Secret.)
end
