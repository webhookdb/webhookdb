# frozen_string_literal: true

workers_count = Integer(ENV.fetch("WEB_CONCURRENCY", 2))
workers workers_count
threads_count = Integer(ENV.fetch("RAILS_MAX_THREADS", 2))
threads threads_count, threads_count

lib = File.expand_path("lib", "#{__dir__}/..")
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

ENV["PROC_MODE"] = "puma"

require "barnes"

require "appydays/dotenviable"
Appydays::Dotenviable.load

raise "No port defined?" unless ENV["PORT"]
port ENV.fetch("PORT", nil)

preload_app!

if workers_count.zero?
  Barnes.start
else
  before_fork do
    Barnes.start
  end
end

on_worker_boot do
  SemanticLogger.reopen if defined?(SemanticLogger)
  if defined?(Webhookdb::Postgres)
    Webhookdb::Postgres.each_model_superclass do |modelclass|
      modelclass.db&.disconnect
    end
  end
end
