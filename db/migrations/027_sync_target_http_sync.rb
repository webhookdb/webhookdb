# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:sync_targets) do
      add_column :page_size, :integer, null: false, default: 500
    end
    alter_table(:organizations) do
      add_column :minimum_sync_seconds, :integer, null: false, default: 10.minutes.to_i
    end
  end
end
