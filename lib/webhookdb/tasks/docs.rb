# frozen_string_literal: true

require "rake/tasklib"
require "sequel"

require "webhookdb"
require "webhookdb/postgres"

module Webhookdb::Tasks
  class Docs < Rake::TaskLib
    def initialize
      super
      namespace :docs do
        desc "Write out auto-generated docs for integrations."
        task :replicators, [:out, :name] do |_, args|
          (out = args[:out]) or raise ArgumentError, "must pass :out param (directory to write files)"
          require "webhookdb/replicator"
          Webhookdb.load_app
          if (rname = args[:name])
            repl = Webhookdb::Replicator.registered!(rname)
            puts self.replicator_md(repl)
          else
            descriptors = Webhookdb::Replicator::Docgen.documentable_descriptors
            descriptors.each do |repl|
              md = self.replicator_md(repl)
              path = File.join(out, "#{repl.name}.md")
              File.write(path, md)
            end
            list_md = Webhookdb::Replicator::Docgen.replicator_list_md(descriptors)
            list_path = File.join(out, "../_includes/replicator_list.md")
            File.write(list_path, list_md)
          end
        end
      end
    end

    # @param desc [Webhookdb::Replicator::Descriptor]
    def replicator_md(desc)
      return Webhookdb::Replicator::Docgen.new(desc).markdown
    end
  end
end
