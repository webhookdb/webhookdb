# frozen_string_literal: true

require "webhookdb"

module Webhookdb::Tasks
  # Load all Webhookdb Rake tasks.
  # You can also load them individually.
  def self.load_all
    require "webhookdb/tasks/admin"
    Webhookdb::Tasks::Admin.new
    require "webhookdb/tasks/annotate"
    Webhookdb::Tasks::Annotate.new
    require "webhookdb/tasks/db"
    Webhookdb::Tasks::DB.new
    require "webhookdb/tasks/docs"
    Webhookdb::Tasks::Docs.new
    require "webhookdb/tasks/fixture"
    Webhookdb::Tasks::Fixture.new
    require "webhookdb/tasks/release"
    Webhookdb::Tasks::Release.new
    require "webhookdb/tasks/message"
    Webhookdb::Tasks::Message.new
    require "webhookdb/tasks/regress"
    Webhookdb::Tasks::Regress.new
    require "webhookdb/tasks/sidekiq"
    Webhookdb::Tasks::Sidekiq.new
    require "webhookdb/tasks/specs"
    Webhookdb::Tasks::Specs.new
  end
end
