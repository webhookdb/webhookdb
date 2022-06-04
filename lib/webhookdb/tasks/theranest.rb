# frozen_string_literal: true

require "rake/tasklib"

require "webhookdb"

module Webhookdb::Tasks
  class Theranest < Rake::TaskLib
    def initialize
      super()
      namespace :theranest do
        desc "Create all theranest integrations"
        task :init, [:org_name, :theranest_username, :theranest_password, :theranest_api] do |_, args|
          Webhookdb.load_app
          # We must create this here, not via the CLI, because we cannot use the normal DB routine.
          org = Webhookdb::Organization.find_or_create(name: args[:org_name])
          unless org.admin_connection_url.present?
            org.admin_connection_url_raw = ENV["DATABASE_URL"]
            org.readonly_connection_url_raw = ENV["DATABASE_URL"]
            org.save_changes
          end

          auth = self.find_or_create_service_integration(org, "theranest_auth_v1")
          auth.update(
            api_url: args[:theranest_api] || "https://theraneststaging.theranest.com",
            backfill_key: args[:theranest_username],
            backfill_secret: args[:theranest_password],
          )

          client = self.find_or_create_service_integration(org, "theranest_client_v1", depends_on: auth)
          case_int = self.find_or_create_service_integration(org, "theranest_case_v1", depends_on: client)
          _progress_note = self.find_or_create_service_integration(
            org,
            "theranest_progress_note_v1",
            depends_on: case_int,
          )
        end
      end
    end

    def find_or_create_service_integration(organization, service_name, depends_on: nil)
      sint = Webhookdb::ServiceIntegration.find_or_create(organization:, service_name:) do |si|
        si.depends_on = depends_on
        si.table_name = service_name + "_#{SecureRandom.hex(2)}"
      end
      sint.service_instance.create_table(if_not_exists: true)
      return sint
    end
  end
end
