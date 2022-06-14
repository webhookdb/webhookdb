# frozen_string_literal: true

require "platform-api"

require "webhookdb"

class Webhookdb::Heroku
  include Appydays::Configurable

  configurable(:heroku) do
    setting :oauth_id, "", key: "WEBHOOKDB_HEROKU_OAUTH_ID"
    setting :oauth_token, "", key: "WEBHOOKDB_HEROKU_OAUTH_TOKEN"
    setting :app_name, "", key: "HEROKU_APP_NAME"
  end

  def self.client
    raise "No heroku:oauth_token configured" if self.oauth_token.blank?
    @client ||= PlatformAPI.connect_oauth(self.oauth_token)
    return @client
  end
end
