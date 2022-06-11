# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:organization_database_migrations) do
      primary_key :id
      timestamptz :created_at, null: false, default: Sequel.function(:now)
      timestamptz :updated_at
      timestamptz :started_at
      timestamptz :finished_at

      foreign_key :organization_id, :organizations, null: false, on_delete: :cascade
      index :organization_id
      index :organization_id, name: :one_inprogress_migration_per_org, unique: true, where: Sequel[finished_at: nil]
      foreign_key :started_by_id, :customers, null: true, on_delete: :set_null

      text :source_admin_connection_url
      text :destination_admin_connection_url
      text :organization_schema

      integer :last_migrated_service_integration_id, null: false, default: 0
      timestamptz :last_migrated_timestamp, null: true
    end
  end
end
