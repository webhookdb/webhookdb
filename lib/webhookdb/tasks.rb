# frozen_string_literal: true

require "webhookdb"

module Webhookdb::Tasks
  # Load all Webhookdb Rake tasks.
  def self.load_all
    Gem.find_files(File.join("webhookdb/tasks/*.rb")).each do |path|
      require path
    end
    Rake::TaskLib.descendants.select { |d| d.to_s.start_with?("Webhookdb::Tasks::") }.each(&:new)
  end
end
