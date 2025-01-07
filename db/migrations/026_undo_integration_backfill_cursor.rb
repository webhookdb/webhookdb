# frozen_string_literal: true

Sequel.migration do
  change do
    # rubocop:disable Sequel/IrreversibleMigration
    alter_table(:service_integrations) do
      drop_column :backfill_cursor
    end
    # rubocop:enable Sequel/IrreversibleMigration
  end
end
