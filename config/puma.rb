# frozen_string_literal: true

# workers Integer(ENV['WEB_CONCURRENCY'] || 1)
# threads_count = Integer(ENV['RAILS_MAX_THREADS'] || 2)
# threads threads_count, threads_count

lib = File.expand_path("lib", "#{__dir__}/..")
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

ENV["PROC_MODE"] = "puma"

require "barnes"

require "appydays/dotenviable"
Appydays::Dotenviable.load

raise "No port defined?" unless ENV["PORT"]
port ENV.fetch("PORT", nil)

preload_app!

on_worker_boot do
  SemanticLogger.reopen if defined?(SemanticLogger)
  if defined?(Webhookdb::Postgres)
    Webhookdb::Postgres.each_model_superclass do |modelclass|
      modelclass.db&.disconnect
    end
  end
end

before_fork do
  Barnes.start
end
