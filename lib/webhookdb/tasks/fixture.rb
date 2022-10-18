# frozen_string_literal: true

require "rake/tasklib"

require "webhookdb"
require "webhookdb/postgres"

module Webhookdb::Tasks
  class Fixture < Rake::TaskLib
    def initialize
      super()
      namespace :fixture do
        desc "Create a bunch of fake integrations and fill them with data."
        task :full do
          require "webhookdb"
          Webhookdb.load_app
          require "webhookdb/fixtures"
          Webhookdb::Fixtures.load_all
          org = Webhookdb::Fixtures.organization.create
          org.prepare_database_connections?
          sints = Array.new(3) { Webhookdb::Fixtures.service_integration(organization: org).create }
          now = Time.now
          sints.each do |sint|
            svc = sint.replicator
            svc.create_table
            Array.new(5000) do |i|
              svc.upsert_webhook_body({"my_id" => i.to_s, "at" => (now - i.seconds).iso8601})
            end
          end
          puts "Created Webhookdb::Organization[#{org.id}]"
        end
      end
    end
  end
end
