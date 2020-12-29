# frozen_string_literal: true

require "rake/tasklib"

require "webhookdb"

module Webhookdb::Tasks
  class Release < Rake::TaskLib
    def initialize
      super()
      desc "Run the release script against the current environment."
      task :release do
        Rake::Task["db:migrate"].invoke
      end
    end
  end
end
