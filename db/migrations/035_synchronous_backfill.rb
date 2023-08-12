# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:organizations) do
      add_column :priority_backfill, :boolean, default: false, null: false
    end
  end
end
