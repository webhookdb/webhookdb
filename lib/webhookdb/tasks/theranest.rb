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
          org.prepare_database_connections

          # Now create an admin user for the org
          daybreak_admin = Webhookdb::Customer.find_or_create(
            email: "webhookdb@lithic.tech",
            password_digest: Webhookdb::Customer::PLACEHOLDER_PASSWORD_DIGEST,
          )
          Webhookdb::OrganizationMembership.find_or_create(
            customer: daybreak_admin,
            organization: org,
            verified: true,
            membership_role: Webhookdb::Role.admin_role,
          )

          # Then all of the Theranest integrations
          auth = self.find_or_create_service_integration(org, "theranest_auth_v1")
          auth.update(
            api_url: args[:theranest_api] || "https://theraneststaging.theranest.com",
            backfill_key: args[:theranest_username],
            backfill_secret: args[:theranest_password],
          )

          client = self.find_or_create_service_integration(org, "theranest_client_v1", depends_on: auth)
          case_int = self.find_or_create_service_integration(org, "theranest_case_v1", depends_on: client)
          progress_note = self.find_or_create_service_integration(
            org,
            "theranest_progress_note_v1",
            depends_on: case_int,
          )
          _progress_note_document = self.find_or_create_service_integration(
            org,
            "theranest_progress_note_document_v1",
            depends_on: progress_note,
          )

          _staff = self.find_or_create_service_integration(org, "theranest_staff_v1", depends_on: auth)
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
