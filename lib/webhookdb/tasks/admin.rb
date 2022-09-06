# frozen_string_literal: true

require "rake/tasklib"

require "webhookdb"

module Webhookdb::Tasks
  class Admin < Rake::TaskLib
    def initialize
      super()
      namespace :admin do
        desc "Add roles to the named org"
        task :role, [:org_key, :role] do |_, args|
          self.setup
          org = self.find_org(args)
          role = Webhookdb::Role.find_or_create(name: args.fetch(:role))
          org.add_feature_role(role)
          puts "Added role #{role.name} to #{org.name}"
        end

        task :backfill, [:org_key] do |_, args|
          self.setup
          org = self.find_org(args)
          org.service_integrations.each do |sint|
            sint.publish_immediate("backfill", sint.id)
          end
        end
      end
    end

    def setup
      Webhookdb.load_app
      Webhookdb::Async.setup_web if Amigo.subscribers.empty?
    end

    def find_org(args)
      org_key = args.fetch(:org_key)
      org = Webhookdb::Organization[key: org_key] or raise "No org with key #{org_key}"
      return org
    end
  end
end
