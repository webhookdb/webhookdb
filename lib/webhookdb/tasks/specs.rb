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

        desc "Run webdriver tests"
        task :webdriver do
          require "rspec/core"
          require "slack-notifier"
          require "webhookdb/spec_helpers/webdriver"
          require "webhookdb/spec_helpers/citest"
          Webhookdb::SpecHelpers::Citest.run_tests("webdriver")
        end
      end
    end
  end
end
