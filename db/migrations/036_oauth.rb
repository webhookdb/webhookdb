# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:oauth_sessions) do
      primary_key :id
      timestamptz :created_at, null: false, default: Sequel.function(:now)

      foreign_key :customer_id, :customers, null: true, on_delete: :cascade
      index :customer_id

      foreign_key :organization_id, :organizations, null: true, on_delete: :cascade

      text :user_agent, null: false
      inet :peer_ip, null: false
      text :oauth_state, null: false
      text :authorization_code, null: true
    end

    alter_table(:testing_pixies) do
      # We're adding this column to the testing pixie to test how non-JSON types are handled by
      # async events on triggered in sequel hooks
      add_column :ip, :inet
    end
  end
end
