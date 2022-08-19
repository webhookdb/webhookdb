# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:service_integrations) do
      drop_column :backfill_cursor
    end
  end
end
