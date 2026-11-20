# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:sync_targets) do
      add_column :disabled, :boolean, default: false, null: false
    end
  end
end
