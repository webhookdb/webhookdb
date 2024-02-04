# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:custom_queries) do
      primary_key :id
      timestamptz :created_at, null: false, default: Sequel.function(:now)
      timestamptz :updated_at
      foreign_key :organization_id, :organizations, null: false, unique: true
      foreign_key :created_by_id, :customers
      text :opaque_id, null: false, unique: true
      text :description, null: false
      text :sql, null: false
      boolean :public, null: false, default: false
    end
  end
end
