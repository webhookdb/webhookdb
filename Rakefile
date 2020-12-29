# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require "appydays/dotenviable"
Appydays::Dotenviable.load

require "raven"

require "webhookdb/tasks/annotate"
Webhookdb::Tasks::Annotate.new
require "webhookdb/tasks/db"
Webhookdb::Tasks::DB.new
require "webhookdb/tasks/heroku"
Webhookdb::Tasks::Heroku.new
require "webhookdb/tasks/release"
Webhookdb::Tasks::Release.new
require "webhookdb/tasks/message"
Webhookdb::Tasks::Message.new
require "webhookdb/tasks/sidekiq"
Webhookdb::Tasks::Sidekiq.new
require "webhookdb/tasks/specs"
Webhookdb::Tasks::Specs.new
