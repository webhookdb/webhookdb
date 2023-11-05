# frozen_string_literal: true

require "amigo/autoscaler"
require "amigo/autoscaler/heroku"
require "webhookdb/async"
require "webhookdb/heroku"

module Webhookdb::Async::Autoscaler
  include Appydays::Configurable
  include Appydays::Loggable

  configurable(:autoscaler) do
    setting :enabled, false
    setting :latency_threshold, 10
    setting :alert_interval, 180
    setting :poll_interval, 30
    setting :max_additional_workers, 2
    setting :latency_restored_threshold, 0
  end

  class << self
    def enabled? = self.enabled

    def start
      raise "already started" unless @instance.nil?
      @impl = Amigo::Autoscaler::Heroku.new(
        heroku: Webhookdb::Heroku.client,
        max_additional_workers: self.max_additional_workers,
      )
      @instance = Amigo::Autoscaler.new(
        poll_interval: self.poll_interval,
        latency_threshold: self.latency_threshold,
        latency_restored_threshold: self.latency_restored_threshold,
        alert_interval: self.alert_interval,
        handlers: [self.method(:scale_up)],
        latency_restored_handlers: [self.method(:scale_down)],
        log: ->(level, msg, kw={}) { self.logger.send(level, msg, kw) },
      )
      return @instance.start
    end

    def scale_up(names_and_latencies, depth:, duration:, **)
      scale_action = @impl.scale_up(names_and_latencies, depth:, duration:, **)
      kw = {queues: names_and_latencies, depth:, duration:, scale_action:}
      self.logger.warn("high_latency_queues_event", **kw)
      Sentry.with_scope do |scope|
        scope.set_extras(**kw)
        Sentry.capture_message("Some queues have a high latency")
      end
    end

    def scale_down(depth:, duration:, **)
      scale_action = @impl.scale_down(depth:, duration:, **)
      self.logger.warn("high_latency_queues_resolved", depth:, duration:, scale_action:)
    end
  end
end
