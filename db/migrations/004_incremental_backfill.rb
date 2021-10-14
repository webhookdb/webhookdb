# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:service_integrations) do
      add_column :last_backfilled_at, :timestamptz
    end
  end
end
