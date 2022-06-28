# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:sync_targets) do
      add_column :last_applied_schema, :text, null: false, default: ""
    end
  end
end
