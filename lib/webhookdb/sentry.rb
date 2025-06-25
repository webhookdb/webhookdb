# frozen_string_literal: true

require "sentry-ruby"
require "appydays/configurable"
require "appydays/loggable"

require "webhookdb"

module Webhookdb::Sentry
  include Appydays::Configurable
  include Appydays::Loggable

  class << self
    def traces_sampler(sampling_context)
      return 0 if self._skip_trace?(sampling_context)
      return sampling_context[:parent_sampled] unless sampling_context[:parent_sampled].nil?
      bias = self._get_specific_trace_rate(sampling_context)
      rate = bias * self.traces_base_sample_rate
      return rate
    end

    SKIP_OPS = Set.new(["queue.publish", "db.redis"])
    def _skip_trace?(sampling_context)
      transaction_ctx = sampling_context[:transaction_context] || {}
      return SKIP_OPS.include?(transaction_ctx[:op])
    end

    def _get_specific_trace_rate(sampling_context)
      transaction_ctx = sampling_context[:transaction_context] || {}
      case transaction_ctx[:op]
          when "http.server"
            # env = sampling_context[:env] # Rack env
            endpoint = transaction_ctx[:name] || ""
            case endpoint
              when "/healthz"
                return self.traces_web_load_sample_rate * 0.1
              when "/sink"
                return 0
              when %r{/v1/service_integrations/\w+$}, "/v1/install/front/intercom/webhook"
                return self.traces_web_load_sample_rate
              else
                return self.traces_web_sample_rate
            end
          when "queue.process"
            klass = transaction_ctx[:name] || "" # Sidekiq/Webhookdb::Jobs::SyncTargetRunSync
            case klass
              when "Sidekiq/Webhookdb::Async::AuditLogger",
                  "Sidekiq/Webhookdb::Jobs::IcalendarSync",
                  "Sidekiq/Webhookdb::Jobs::ProcessWebhook",
                  "Sidekiq/Amigo::Router"
                return self.traces_job_load_sample_rate
              else
                return self.traces_job_sample_rate
            end
        end
      return 1
    end
  end

  configurable(:sentry) do
    setting :dsn, ""
    setting :log_level, :warn
    # Baseline all other trace configurations refer to.
    # Turning this down will proportionately reduce all other traces.
    setting :traces_base_sample_rate, 0.1
    # Rate for most web requests, relative to base rate.
    setting :traces_web_sample_rate, 1
    # Rate for high-throughput "webhook" endpoints, like service integrations and 'install' calls,
    # relative to base rate.
    setting :traces_web_load_sample_rate, 0.05
    # Rate for most jobs, relative to base rate.
    setting :traces_job_sample_rate, 0.1
    # Rate for high-throughput process webhook jobs, relative to base rate.
    setting :traces_job_load_sample_rate, 0.05

    # Apply the current configuration to Sentry.
    # See https://docs.sentry.io/clients/ruby/config/ for more info.
    after_configured do
      if self.dsn
        # See https://github.com/getsentry/sentry-ruby/issues/1756
        require "sentry-sidekiq"
        Sentry.init do |config|
          config.dsn = dsn
          config.sdk_logger = self.logger
          config.sdk_logger.level = self.log_level
          config.traces_sampler = ->(ctx) { self.traces_sampler(ctx) }
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
