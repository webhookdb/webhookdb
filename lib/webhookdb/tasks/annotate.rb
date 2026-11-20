# frozen_string_literal: true

require "rake/tasklib"
require "sequel"

require "webhookdb"
require "webhookdb/postgres"

module Webhookdb::Tasks
  class Annotate < Rake::TaskLib
    def initialize
      super
      desc "Update model annotations"
      task :annotate do
        unless `git diff`.blank?
          puts "Cannot annotate while there is any git diff."
          puts "Please commit or revert any diff and try again."
          exit(1)
        end

        require "webhookdb"
        Webhookdb.load_app
        files = []
        Webhookdb::Postgres.each_model_class do |cls|
          files << "lib/#{cls.name.underscore}.rb" if cls.name
        end

        require "sequel/annotate"
        Sequel::Annotate.annotate(files, border: true)
        puts "Finished annotating:"
        files.each { |f| puts "  #{f}" }
        puts "Please commit the changes."
      end
    end
  end
end
