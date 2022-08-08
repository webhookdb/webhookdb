# frozen_string_literal: true

Sequel.migration do
  down do
    alter_table(:service_integrations) do
      drop_column :backfill_cursor
    end
  end
end
