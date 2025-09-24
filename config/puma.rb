# frozen_string_literal: true

lib = File.expand_path("lib", "#{__dir__}/..")
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

ENV["PROC_MODE"] = "puma"

require "appydays/dotenviable"
Appydays::Dotenviable.load

workers_count = Integer(ENV.fetch("WEB_CONCURRENCY", 2))
workers workers_count
threads_count = Integer(ENV.fetch("RAILS_MAX_THREADS", 2))
threads threads_count, threads_count

raise "No port defined?" unless ENV["PORT"]
port ENV.fetch("PORT", nil)

preload_app!

# Start these in the parent process.
# They are on threads which will not run in the child processes (see Unix fork(2) docs).
require "webhookdb/procmon"
Webhookdb::Procmon.run if Webhookdb::Procmon.enabled
require "webhookdb/async/autoscaler"

Webhookdb::Async::Autoscaler.build.start if Webhookdb::Async::Autoscaler.enabled
require "webhookdb/async/web_autoscaler"
if Webhookdb::Async::WebAutoscaler.enabled
  Webhookdb::Async::WebAutoscaler.build.start
  amigo_autoscaler_interval Webhookdb::Async::WebAutoscaler.poll_interval
  amigo_puma_pool_usage_checker Webhookdb::Async::WebAutoscaler.puma_pool_usage_checker
  plugin :amigo
end

require "barnes"

# Load the appropriate code based on if we're running clustered or not.
# If we are not clustered, just start Barnes.
# If we are, then start Barnes before the fork, and reconnect files and database conns after the fork.
if workers_count.zero?
  Barnes.start
else
  before_fork do
    Barnes.start
  end

  on_worker_boot do |idx|
    ENV["PUMA_WORKER"] = idx.to_s
    SemanticLogger.reopen if defined?(SemanticLogger)
    if defined?(Webhookdb::Postgres)
      Webhookdb::Postgres.each_model_superclass do |modelclass|
        modelclass.db&.disconnect
      end
    end
  end
end
