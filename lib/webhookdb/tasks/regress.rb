# frozen_string_literal: true

require "rake/tasklib"
require "sequel"

require "webhookdb"
require "webhookdb/postgres"

module Webhookdb::Tasks
  class Regress < Rake::TaskLib
    def initialize
      super()
      namespace :regress do
        desc "Creates databases for all orgs that do not have them."
        task :prepare do
          Webhookdb.load_app
          Webhookdb::Organization.where(readonly_connection_url_raw: nil).each do |org|
            org.prepare_database_connections
            org.migrate_replication_tables
          end
        end

        desc "Prints out all service integrations that have untrimmed logged webhooks."
        task :list_available do
          Webhookdb.load_app
          opaque_ids = Webhookdb::LoggedWebhook.where(truncated_at: nil).
            distinct(:service_integration_opaque_id).
            select_map(:service_integration_opaque_id)
          sints = Webhookdb::ServiceIntegration.where(opaque_id: opaque_ids).all
          self.print_service_integrations(sints)
        end

        desc "Replay the last :count webhooks going to the service integration with the given opaque id. " \
             "Use -1 for all webhooks."
        task :replay, [:opaque_id, :count] do |_, args|
          opaque_id = args.fetch(:opaque_id)
          count = args.fetch(:count).to_i
          Webhookdb.load_app
          ds = Webhookdb::LoggedWebhook.where(truncated_at: nil).
            where(service_integration_opaque_id: opaque_id).
            order(Sequel.asc(:inserted_at))
          ds = ds.limit(count) if count >= 0
          ds.paged_each do |lw|
            good = lw.retry_one
            puts "#{lw.pk} failed" unless good
          end
        end

        desc "Prints out all service integrations that have backfill info available."
        task :list_backfill do
          Webhookdb.load_app
          sints = Webhookdb::ServiceIntegration.exclude(backfill_key: nil).all
          self.print_service_integrations(sints)
        end

        desc "Runs a backfill for the service integration with the given opaque id. " \
             "Regression backfills are limited to one page."
        task :backfill, [:opaque_id] do |_, args|
          opaque_id = args.fetch(:opaque_id)
          Webhookdb.load_app
          sint = Webhookdb::ServiceIntegration[opaque_id:] or raise "No service integration for #{opaque_id}"
          sint.replicator.backfill
        end
      end
    end

    def print_service_integrations(iter)
      rows = iter.map do |sint|
        name = "#{sint.organization.name} (#{sint.organization_id})"
        [name, sint.service_name, sint.opaque_id, sint.table_name]
      end
      rows.sort!
      self.table_print rows
    end

    def table_print(rows)
      max_lengths = rows.each_with_object({}) do |row, m|
        row.each_with_index { |value, idx| m[idx] = [m.fetch(idx, 0), value.to_s.length].max }
      end
      row_strings = rows.map do |row|
        row.each_with_index.map { |value, idx| "%-#{max_lengths[idx]}s" % value }.join("\t")
      end
      puts row_strings
    end
  end
end
