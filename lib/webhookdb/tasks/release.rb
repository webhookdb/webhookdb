# frozen_string_literal: true

require "rake/tasklib"

require "webhookdb"

module Webhookdb::Tasks
  class Release < Rake::TaskLib
    def initialize
      super
      desc "Migrate replication tables for each integration, ensure all columns and backfill new columns."
      task :migrate_replication_tables do
        Webhookdb.load_app
        Webhookdb::Organization.enqueue_migrate_all_replication_tables
      end

      desc "Run the release script against the current environment."
      task :release do
        Rake::Task["db:migrate"].invoke
        Rake::Task["migrate_replication_tables"].invoke
        if ENV["HEROKU_APP_ID"] && (ENV["RUN_INTEGRATION_TESTS_ON_RELEASE"] == "true")
          Rake::Task["specs:heroku_integration_step1"].invoke
        end
      end

      desc "Print version info and exit"
      task :version do
        sha = Webhookdb::COMMIT[..8]
        puts "#{sha} (#{Webhookdb::RELEASE}) - #{Webhookdb::RELEASE_CREATED_AT} - #{Webhookdb::RACK_ENV}"
      end
    end
  end
end
