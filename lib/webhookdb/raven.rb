# frozen_string_literal: true

require "raven"
require "appydays/configurable"
require "appydays/loggable"

require "webhookdb"

module Webhookdb::Raven
  include Appydays::Configurable
  include Appydays::Loggable

  configurable(:raven) do
    setting :dsn, ""

    # Apply the current configuration to Raven.
    # See https://docs.sentry.io/clients/ruby/config/ for more info.
    after_configured do
      if self.dsn
        Raven.configure do |raven_config|
          raven_config.dsn = dsn
          raven_config.logger = self.logger
          raven_config.processors -= [Raven::Processor::PostData]
        end
      end
    end
  end

  def self.enabled?
    return self.dsn.present?
  end
end
