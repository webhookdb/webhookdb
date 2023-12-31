# frozen_string_literal: true

require "amigo/autoscaler"
require "amigo/autoscaler/heroku"
require "webhookdb/async"
require "webhookdb/heroku"

module Webhookdb::Async::Autoscaler
  include Appydays::Configurable
  include Appydays::Loggable

  AVAILABLE_PROVIDERS = ["heroku"].freeze

  def self._check_provider!
    return if AVAILABLE_PROVIDERS.include?(self.provider)
    return if !self.enabled && self.provider.blank?
    raise "invalid AUTOSCALER_PROVIDER: '#{self.provider}', one of: #{AVAILABLE_PROVIDERS.join(', ')}"
  end

  configurable(:autoscaler) do
    setting :enabled, false
    setting :provider, ""
    setting :latency_threshold, 10
    setting :alert_interval, 180
    setting :poll_interval, 30
    setting :max_additional_workers, 2
    setting :latency_restored_threshold, 0
    setting :hostname_regex, /^web\.1$/, convert: ->(s) { Regexp.new(s) }

    after_configured do
      self._check_provider!
    end
  end

  class << self
    def enabled? = self.enabled

    def start
      raise "already started" unless @instance.nil?
      case self.provider
        when "heroku"
          opts = {heroku: Webhookdb::Heroku.client, max_additional_workers: self.max_additional_workers}
          (opts[:app_id_or_app_name] = self.heroku_app_id_or_app_name) if
            self.heroku_app_id_or_app_name
          (opts[:formation_id_or_formation_type] = self.heroku_formation_id_or_formation_type) if
            self.heroku_formation_id_or_formation_type
          @impl = Amigo::Autoscaler::Heroku.new(**opts)
        else
          self._check_provider!
      end
      @instance = Amigo::Autoscaler.new(
        poll_interval: self.poll_interval,
        latency_threshold: self.latency_threshold,
        hostname_regex: self.hostname_regex,
        handlers: [self.method(:scale_up)],
        alert_interval: self.alert_interval,
        latency_restored_threshold: self.latency_restored_threshold,
        latency_restored_handlers: [self.method(:scale_down)],
        log: ->(level, msg, kw={}) { self.logger.send(level, msg, kw) },
      )
      return @instance.start
    end

    def stop
      raise "not started" if @instance.nil?
      @instance.stop
    end

    def scale_up(names_and_latencies, depth:, duration:, **)
      scale_action = @impl.scale_up(names_and_latencies, depth:, duration:, **)
      kw = {queues: names_and_latencies, depth:, duration:, scale_action:}
      self.logger.warn("high_latency_queues_event", **kw)
      Sentry.with_scope do |scope|
        scope&.set_extras(**kw)
        Sentry.capture_message("Some queues have a high latency")
      end
    end

    def scale_down(depth:, duration:, **)
      scale_action = @impl.scale_down(depth:, duration:, **)
      self.logger.warn("high_latency_queues_resolved", depth:, duration:, scale_action:)
    end
  end
end
