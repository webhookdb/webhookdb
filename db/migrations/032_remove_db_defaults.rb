# frozen_string_literal: true

Sequel.migration do
  change do
    # rubocop:disable Sequel/IrreversibleMigration
    alter_table(:sync_targets) do
      set_column_default :page_size, nil
    end
    alter_table(:organizations) do
      set_column_default :minimum_sync_seconds, nil
    end
    # rubocop:enable Sequel/IrreversibleMigration
  end
end
