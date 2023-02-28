# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:sync_targets) do
      set_column_default :page_size, nil
    end
    alter_table(:organizations) do
      set_column_default :minimum_sync_seconds, nil
    end
  end
end
