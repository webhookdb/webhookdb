# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:organization_error_handlers) do
      primary_key :id
      timestamptz :created_at, null: false, default: Sequel.function(:now)
      timestamptz :updated_at

      text :opaque_id, null: false, unique: true

      foreign_key :organization_id, :organizations, null: false
      foreign_key :created_by_id, :customers, null: true, on_delete: :set_null

      text :service, null: false
      text :sentry_dsn, null: false, default: ""
      text :sentry_project_id, null: false, default: ""
      text :sentry_host, null: false, default: ""

      jsonb :emails, null: false, default: '[]'
    end
  end
end
