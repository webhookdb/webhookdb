# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:sync_targets) do
      add_column :page_size, :integer, null: false, default: 500
    end
  end
end
