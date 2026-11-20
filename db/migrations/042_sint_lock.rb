# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:backfill_job_service_integration_locks) do
      primary_key :id
      foreign_key :service_integration_id, :service_integrations, null: false, on_delete: :cascade, unique: true
    end
  end
end
