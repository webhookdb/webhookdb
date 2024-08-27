# frozen_string_literal: true

require "webhookdb/async/scheduled_job"
require "webhookdb/jobs"

# Log out some metrics every minute.
class Webhookdb::Jobs::MonitorMetrics
  extend Webhookdb::Async::ScheduledJob

  cron "* * * * *" # Every 1 minute
  splay 0

  def _perform
    opts = {}
    max_size = 0
    max_latency = 0
    Sidekiq::Queue.all.each do |q|
      size = q.size
      latency = q.latency
      max_size = [max_size, size].max
      max_latency = [max_latency, latency].max
      opts["#{q.name}_size"] = size
      opts["#{q.name}_latency"] = latency
    end
    opts[:max_size] = max_size
    opts[:max_latency] = max_latency
    self.logger.info("metrics_monitor_queue", **opts)
  end
end
