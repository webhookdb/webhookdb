# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:database_documents) do
      primary_key :id
      timestamptz :created_at, null: false, default: Sequel.function(:now)

      text :key, null: false, unique: true
      bytea :content, null: false
      text :content_type, null: false
      text :encryption_secret, null: false
    end
  end
end
