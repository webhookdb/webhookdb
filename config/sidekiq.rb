# frozen_string_literal: true

lib = File.expand_path("lib", "#{__dir__}/..")
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require "appydays/dotenviable"
Appydays::Dotenviable.load

require "webhookdb"
Webhookdb.load_app

require "webhookdb/async"
Webhookdb::Async.require_jobs
Webhookdb::Async.register_subscriber
Webhookdb::Async.start_scheduler
Raven.tags_context(application: "worker")
