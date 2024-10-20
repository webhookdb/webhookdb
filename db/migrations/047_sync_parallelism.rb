# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:sync_targets) do
      add_column :parallelism, :integer, null: false, default: 0
    end
  end
end
