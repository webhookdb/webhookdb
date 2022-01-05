# frozen_string_literal: true

require "rake/tasklib"

require "webhookdb"

module Webhookdb::Tasks
  class Sidekiq < Rake::TaskLib
    def initialize
      super()
      namespace :sidekiq do
        desc "Clear the Sidekiq redis DB (flushdb). " \
             "Only use on local, and only for legit reasons, " \
             "not to paper over problems that will show on staging and prod " \
             "(like removing a job class)."
        task :reset do
          require "webhookdb/async"
          ::Sidekiq.redis(&:flushdb)
        end
      end
    end
  end
end
