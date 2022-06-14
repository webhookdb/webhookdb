# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require "appydays/dotenviable"
Appydays::Dotenviable.load

require "sentry-ruby"

require "webhookdb/tasks/annotate"
Webhookdb::Tasks::Annotate.new
require "webhookdb/tasks/db"
Webhookdb::Tasks::DB.new
require "webhookdb/tasks/fixture"
Webhookdb::Tasks::Fixture.new
require "webhookdb/tasks/release"
Webhookdb::Tasks::Release.new
require "webhookdb/tasks/message"
Webhookdb::Tasks::Message.new
require "webhookdb/tasks/sidekiq"
Webhookdb::Tasks::Sidekiq.new
require "webhookdb/tasks/specs"
Webhookdb::Tasks::Specs.new
require "webhookdb/tasks/theranest"
Webhookdb::Tasks::Theranest.new
