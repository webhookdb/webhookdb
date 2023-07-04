# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:backfill_jobs) do
      primary_key :id
      timestamptz :created_at, null: false, default: Sequel.function(:now)
      timestamptz :updated_at

      timestamptz :started_at
      timestamptz :finished_at

      text :opaque_id, null: false, unique: true

      foreign_key :service_integration_id, :service_integrations, null: false, on_delete: :cascade
      index :service_integration_id

      foreign_key :parent_job_id, :backfill_jobs
      index :parent_job_id

      foreign_key :created_by_id, :customers, null: true, on_delete: :set_null

      boolean :incremental, null: false
    end
  end
end
