# frozen_string_literal: true

require "amigo/autoscaler"
require "webhookdb/async"

module Webhookdb::Async::Autoscaler
  include Appydays::Configurable

  configurable(:autoscaler) do
    setting :latency_threshold, 5
    setting :alert_interval, 120
    setting :poll_interval, 20
    setting :hostname_regex, '^worker\\.1$'
    setting :handlers, "sentry,log"
  end

  class << self
    def start
      raise "already started" unless @instance.nil?

      @instance = Amigo::Autoscaler.new(
        poll_interval: self.poll_interval,
        latency_threshold: self.latency_threshold,
        hostname_regex: Regexp.new(self.hostname_regex),
        handlers: self.handlers.split(","),
        alert_interval: self.alert_interval,
      )
      return @instance.start
    end
  end
end
