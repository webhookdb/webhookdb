# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:saved_views) do
      primary_key :id
      timestamptz :created_at, null: false, default: Sequel.function(:now)
      timestamptz :updated_at

      foreign_key :organization_id, :organizations, null: false, on_delete: :cascade
      index :organization_id

      text :name, null: false
      unique [:organization_id, :name]
      text :sql, null: false

      foreign_key :created_by_id, :customers, null: true, on_delete: :set_null
    end
  end
end
