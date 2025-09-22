# frozen_string_literal: true

require "amigo/autoscaler"
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
    setting :alert_interval, 20
    setting :poll_interval, 15
    setting :max_additional_workers, 2
    setting :hostname_regex, /^web\.2$/, convert: ->(s) { Regexp.new(s) }
  end

  class << self
    def build
      return Webhookdb::Async::Autoscaler.build_common(
        handlers: self.handlers,
        logger: self.logger,
        max_additional_workers: self.max_additional_workers,
        formation: "web",
        sentry_message: "Web requests have a high latency",
        log_message: "high_latency_requests",
        checker: Amigo::Autoscaler::Checkers::WebLatency.new(redis: Webhookdb::Redis.cache),
        poll_interval: self.poll_interval,
        latency_threshold: self.latency_threshold,
        hostname_regex: self.hostname_regex,
        alert_interval: self.alert_interval,
        namespace: NAMESPACE,
      )
    end
  end
end
