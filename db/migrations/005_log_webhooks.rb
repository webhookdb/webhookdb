# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:logged_webhooks) do
      primary_key :id, type: :bigserial
      timestamptz :inserted_at, null: false, default: Sequel.function(:now)
      index :inserted_at
      timestamptz :truncated_at

      text :request_body, null: false
      jsonb :request_headers, null: false
      smallint :response_status, null: false

      # This could be invalid so is not an FK
      text :service_integration_opaque_id, null: false
      index :service_integration_opaque_id

      # Org is null if opaque id is invalid
      foreign_key :organization_id, :organizations, on_delete: :cascade
      index :organization_id
    end
  end
end
