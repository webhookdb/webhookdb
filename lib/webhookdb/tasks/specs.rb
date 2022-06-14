# frozen_string_literal: true

require "rake/tasklib"
require "stringio"

require "webhookdb"

module Webhookdb::Tasks
  class Specs < Rake::TaskLib
    def initialize
      super()
      namespace :specs do
        desc "Run API integration tests"
        task :integration do
          require "rspec/core"
          require "slack-notifier"
          require "webhookdb/spec_helpers/integration"
          require "webhookdb/spec_helpers/citest"
          Webhookdb::SpecHelpers::Citest.run_tests("integration")
        end

        desc "See README."
        task :integration_step1 do
          require "webhookdb/heroku"
          Webhookdb::Heroku.client.dyno.create(
            Webhookdb::Heroku.app_name,
            command: "bundle exec rake specs:integration_step2",
            attach: false,
            time_to_live: 1.minute.to_i,
            type: "run",
          )
        end
        task :integration_step2 do
          sleep(20)
          require "webhookdb/heroku"
          Webhookdb::Heroku.client.dyno.create(
            Webhookdb::Heroku.app_name,
            command: "bundle exec rake specs:integration_step3",
            env: {"INTEGRATION_TESTS" => "true"},
            attach: false,
            time_to_live: 10.minute.to_i,
            type: "run",
          )
        end
        task :integration_step3 do
          require "webhookdb/heroku"
          Rake::Task["specs:integration"].invoke
        end

        desc "Do a thing through Rake so it's easy to run under the debugger"
        task :debugtask do
          puts "Put the code that you want to run here"
        end
      end
    end
  end
end
