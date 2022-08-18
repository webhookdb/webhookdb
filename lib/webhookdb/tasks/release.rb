# frozen_string_literal: true

require "rake/tasklib"

require "webhookdb"

module Webhookdb::Tasks
  class Release < Rake::TaskLib
    def initialize
      super()
      desc "Migrate replication tables for each integration, ensure all columns and backfill new columns."
      task :migrate_replication_tables do
        Webhookdb.load_app
        Webhookdb::Organization.enqueue_migrate_all_replication_tables
      end

      desc "Run the release script against the current environment."
      task :release do
        Rake::Task["db:migrate"].invoke
        Rake::Task["migrate_replication_tables"].invoke
      end
    end
  end
end
