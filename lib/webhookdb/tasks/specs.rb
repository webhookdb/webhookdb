# frozen_string_literal: true

require "rake/tasklib"
require "stringio"

require "webhookdb"

module Webhookdb::Tasks
  class Specs < Rake::TaskLib
    def initialize
      super()
      namespace :specs do
        desc "Run API integration tests in the 'integration' folder of this gem. " \
             "To run your own tests, create a task similar to this one, " \
             "that calls Webhookdb::SpecHelpers::Citest.run_tests."
        task :integration do
          require "rspec/core"
          require "slack-notifier"
          require "webhookdb/spec_helpers/integration"
          require "webhookdb/spec_helpers/citest"
          Webhookdb::SpecHelpers::Citest.run_tests(Webhookdb::SpecHelpers::Citest::INTEGRATION_TESTS_DIR)
        end

        desc "The release process needs to finish quickly, so start the integration tests in another dyno."
        task :heroku_integration_step1 do
          require "webhookdb/heroku"
          Webhookdb::Heroku.client.dyno.create(
            Webhookdb::Heroku.app_name,
            command: "bundle exec rake specs:heroku_integration_step2",
            attach: false,
            time_to_live: 1.minute.to_i,
            type: "run",
          )
        end
        desc "Sleep 20 seconds to wait for the **next** one-off dyno to have the new code."
        task :heroku_integration_step2 do
          sleep(20)
          require "webhookdb/heroku"
          Webhookdb::Heroku.client.dyno.create(
            Webhookdb::Heroku.app_name,
            command: "bundle exec rake specs:heroku_integration_step3",
            env: {"INTEGRATION_TESTS" => "true"},
            attach: false,
            time_to_live: 10.minute.to_i,
            type: "run",
          )
        end
        desc "Run the actual integration tests."
        task :heroku_integration_step3 do
          require "webhookdb/heroku"
          Rake::Task["specs:integration"].invoke
        end

        desc "Do a thing through Rake so it's easy to run under the debugger"
        task :debugtask do
          require "webhookdb"
          Webhookdb.load_app
          sint = Webhookdb::ServiceIntegration[84]
          row_pk = 710
          expiring_before = 1.week.from_now
          sint.replicator.renew_watch_channel(row_pk:, expiring_before:)
        end
      end
    end
  end
end
