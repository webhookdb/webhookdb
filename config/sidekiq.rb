# frozen_string_literal: true

lib = File.expand_path("lib", "#{__dir__}/..")
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require "appydays/dotenviable"
Appydays::Dotenviable.load

require "webhookdb"
Webhookdb.load_app
Sentry.configure_scope do |scope|
  scope.set_tags(application: "worker")
end

require "webhookdb/async"
Webhookdb::Async.require_jobs
Webhookdb::Async.register_subscriber
Webhookdb::Async.start_scheduler
