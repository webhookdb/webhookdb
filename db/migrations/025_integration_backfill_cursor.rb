# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:service_integrations) do
      add_column :backfill_cursor, :text, null: true
    end
  end
end
