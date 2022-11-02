# frozen_string_literal: true

require "amigo"

# When queues achieve a latency that is too high,
# take some action.
# You should start this up at Sidekiq application startup:
#
# # sidekiq.rb
# Amigo::Autoscaler.new.start
#
# Right now, this is pretty simple- we alert any time
# there is a latency over a threshold.
#
# In the future, we can:
#
# 1) actually autoscale rather than just alert
#    (this may take the form of a POST to a configurable endpoint),
# 2) become more sophisticated with how we detect latency growth.
#
class Amigo::Autoscaler
  # How often should Autoscaler check for latency?
  # @return [Integer]
  attr_reader :poll_interval
  # What latency should we alert on?
  # @return [Integer]
  attr_reader :latency_threshold
  # What hosts/processes should this run on?
  # Look at ENV['DYNO'] and Socket.gethostname.
  # Default to only run on 'worker.1', which is the first Heroku worker dyno.
  # @return [Regexp]
  attr_reader :hostname_regex
  # Methods to call when alerting.
  # @return [Array<String>]
  attr_reader :handlers
  # Only alert this often.
  # For example, with poll_interval of 10 seconds
  # and alert_interval of 200 seconds,
  # we'd alert once and then 210 seconds later.
  # @return [Integer]
  attr_reader :alert_interval

  def initialize(
    poll_interval: 20,
    latency_threshold: 5,
    hostname_regex: /^worker\.1$/,
    handlers: ["log"],
    alert_interval: 120
  )

    @poll_interval = poll_interval
    @latency_threshold = latency_threshold
    @hostname_regex = hostname_regex
    @handlers = handlers.map(&:strip)
    @alert_interval = alert_interval
  end

  def polling_thread
    return @polling_thread
  end

  def setup
    @alert_methods = self.handlers.map do |a|
      meth = "alert_#{a}".to_sym
      raise "Invalid alert mechanism '#{a}'" unless self.method(meth)
      meth
    end
    @last_alerted = Time.at(0)
    @stop = false
  end

  def start
    raise "already started" unless @polling_thread.nil?

    hostname = ENV.fetch("DYNO") { Socket.gethostname }
    return false unless self.hostname_regex.match?(hostname)

    self.log(:info, "async_autoscaler_starting")
    self.setup
    @polling_thread = Thread.new do
      until @stop
        Kernel.sleep(self.poll_interval)
        self.check unless @stop
      end
    end
    return true
  end

  def stop
    @stop = true
  end

  def check
    now = Time.now
    skip_check = now < (@last_alerted + self.poll_interval)
    if skip_check
      self.log(:debug, "async_autoscaler_skip_check")
      return
    end
    self.log(:info, "async_autoscaler_check")
    high_latency_queues = Sidekiq::Queue.all.
      map { |q| [q.name, q.latency] }.
      select { |(_, latency)| latency > self.latency_threshold }.
      to_h
    return if high_latency_queues.empty?
    @alert_methods.each { |m| self.send(m, high_latency_queues) }
    @last_alerted = now
  end

  def alert_sentry(names_and_latencies)
    Sentry.with_scope do |scope|
      scope.set_extras(high_latency_queues: names_and_latencies)
      names = names_and_latencies.map(&:first).sort.join(", ")
      Sentry.capture_message("Some queues have a high latency: #{names}")
    end
  end

  def alert_log(names_and_latencies)
    self.log(:warn, "high_latency_queues", queues: names_and_latencies)
  end

  def alert_test(_names_and_latencies); end

  protected def log(level, msg, **kw)
    Amigo.log(nil, level, msg, kw)
  end
end
