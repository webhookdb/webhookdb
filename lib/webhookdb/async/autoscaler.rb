# frozen_string_literal: true

require "amigo/autoscaler"
require "amigo/autoscaler/checkers/sidekiq"
require "amigo/autoscaler/handlers/chain"
require "amigo/autoscaler/handlers/heroku"
require "amigo/autoscaler/handlers/log"
require "amigo/autoscaler/handlers/sentry"
require "webhookdb/async"
require "webhookdb/heroku"

module Webhookdb::Async::Autoscaler
  include Appydays::Configurable
  include Appydays::Loggable

  NAMESPACE = "amigo/autoscaler"

  configurable(:autoscaler) do
    setting :enabled, false
    # The log handler is always used.
    # If 'sentry' is in the string, use the Sentry handler.
    # If 'heroku' is in the string, use the Sentry handler.
    setting :handlers, "sentry"
    setting :latency_threshold, 10.0
    setting :alert_interval, 180
    setting :poll_interval, 30
    setting :max_additional_workers, 2
    setting :latency_restored_threshold, 0
    setting :hostname_regex, /^web\.1$/, convert: ->(s) { Regexp.new(s) }
    setting :heroku_formation_id_or_formation_type, "worker"
    setting :sentry_alert_interval, 180
  end

  class << self
    def build
      return build_common(
        handlers: self.handlers,
        logger: self.logger,
        max_additional_workers: self.max_additional_workers,
        formation: self.heroku_formation_id_or_formation_type,
        sentry_message: "Some queues have a high latency",
        log_message: "high_latency_queues",
        checker: Amigo::Autoscaler::Checkers::Sidekiq.new,
        poll_interval: self.poll_interval,
        latency_threshold: self.latency_threshold,
        hostname_regex: self.hostname_regex,
        alert_interval: self.alert_interval,
        latency_restored_threshold: self.latency_restored_threshold,
        namespace: NAMESPACE,
      )
    end

    def build_common(
      handlers:,
      logger:,
      max_additional_workers:,
      formation:,
      log_message:,
      sentry_message:,
      checker:,
      **
    )
      chain = [
        Amigo::Autoscaler::Handlers::Log.new(
          message: log_message,
          log: ->(level, msg, kw={}) { logger.send(level, msg, kw) },
        ),
      ]
      if handlers&.include?("sentry")
        chain << Amigo::Autoscaler::Handlers::Sentry.new(
          message: sentry_message,
          interval: self.sentry_alert_interval,
        )
      end
      if handlers&.include?("heroku")
        chain << Amigo::Autoscaler::Handlers::Heroku.new(
          client: Webhookdb::Heroku.client,
          formation:,
          max_additional_workers:,
          app_id_or_app_name: Webhookdb::Heroku.app_name,
        )
      end
      return Amigo::Autoscaler.new(
        **,
        on_unhandled_exception: ->(e) { Sentry.capture_exception(e) },
        handler: Amigo::Autoscaler::Handlers::Chain.new(chain),
        checker:,
      )
    end
  end
end
