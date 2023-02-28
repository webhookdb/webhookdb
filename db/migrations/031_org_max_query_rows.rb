# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:organizations) do
      add_column :max_query_rows, :integer, null: true
    end
  end
end
