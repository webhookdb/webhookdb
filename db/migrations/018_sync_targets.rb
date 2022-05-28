# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:sync_targets) do
      primary_key :id
      timestamptz :created_at, null: false, default: Sequel.function(:now)
      timestamptz :updated_at

      text :opaque_id, null: false, unique: true
      foreign_key :service_integration_id, :service_integrations, null: false, on_delete: :cascade
      index :service_integration_id
      foreign_key :created_by_id, :customers, null: true, on_delete: :set_null

      integer :period_seconds, null: false
      text :connection_url, null: false

      text :schema, null: false, default: ""
      text :table, null: false, default: ""

      timestamptz :last_synced_at
      index :last_synced_at
    end
  end
end
