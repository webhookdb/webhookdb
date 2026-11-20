# frozen_string_literal: true

require "amigo/autoscaler"
require "amigo/autoscaler/checkers/chain"
require "amigo/autoscaler/checkers/puma_pool_usage"
require "amigo/autoscaler/checkers/web_latency"

require "webhookdb/async"
require "webhookdb/async/autoscaler"
require "webhookdb/heroku"

module Webhookdb::Async::WebAutoscaler
  include Appydays::Configurable
  include Appydays::Loggable

  NAMESPACE = "amigo/web_autoscaler"

  configurable(:web_autoscaler) do
    setting :enabled, false
    # The log handler is always used.
    # If 'sentry' is in the string, use the Sentry handler.
    # If 'heroku' is in the string, use the Sentry handler.
    setting :handlers, "sentry"
    # Over 5s, start scaling. Under 5s, we can start scaling down.
    setting :latency_threshold, 4.0
    # Scale if our pool is over 85% used.
    setting :usage_threshold, 0.85
    setting :alert_interval, 20
    setting :poll_interval, 15
    setting :max_additional_workers, 2
    setting :hostname_regex, /^web\.2$/, convert: ->(s) { Regexp.new(s) }
  end

  class << self
    def puma_pool_usage_checker
      @puma_pool_usage_checker ||= Amigo::Autoscaler::Checkers::PumaPoolUsage.new(redis: Webhookdb::Redis.cache)
      return @puma_pool_usage_checker
    end

    def build
      return Webhookdb::Async::Autoscaler.build_common(
        handlers: self.handlers,
        logger: self.logger,
        max_additional_workers: self.max_additional_workers,
        formation: "web",
        sentry_message: "Web requests have a high latency",
        log_message: "high_latency_requests",
        checker: Amigo::Autoscaler::Checkers::Chain.new(
          [
            Amigo::Autoscaler::Checkers::WebLatency.new(redis: Webhookdb::Redis.cache),
            self.puma_pool_usage_checker,
          ],
        ),
        poll_interval: self.poll_interval,
        latency_threshold: self.latency_threshold,
        usage_threshold: self.usage_threshold,
        hostname_regex: self.hostname_regex,
        alert_interval: self.alert_interval,
        namespace: NAMESPACE,
      )
    end
  end
end
