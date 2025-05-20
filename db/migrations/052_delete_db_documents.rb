# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:database_documents) do
      add_column :delete_at, :timestamptz, index: true
    end
  end
end
