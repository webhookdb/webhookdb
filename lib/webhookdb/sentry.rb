# frozen_string_literal: true

require "sentry-ruby"
require "appydays/configurable"
require "appydays/loggable"

require "webhookdb"

module Webhookdb::Sentry
  include Appydays::Configurable
  include Appydays::Loggable

  configurable(:sentry) do
    setting :dsn, ""
    setting :log_level, :warn

    # Apply the current configuration to Sentry.
    # See https://docs.sentry.io/clients/ruby/config/ for more info.
    after_configured do
      if self.dsn
        # See https://github.com/getsentry/sentry-ruby/issues/1756
        require "sentry-sidekiq"
        Sentry.init do |config|
          config.dsn = dsn
          config.logger = self.logger
          config.logger.level = self.log_level
        end
      else
        Sentry.instance_variable_set(:@main_hub, nil)
      end
    end
  end

  def self.enabled?
    return self.dsn.present?
  end
end
