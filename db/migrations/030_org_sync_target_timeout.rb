# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:organizations) do
      add_column :sync_target_timeout, :integer, null: false, default: 30
    end
  end
end
