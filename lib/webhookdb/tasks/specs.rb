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

        desc "Do a thing through Rake so it's easy to run under the debugger"
        task :debugtask do
          puts "Put the code that you want to run here"
        end
      end
    end
  end
end
