# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:organizations) do
      add_column :replication_schema, :text, null: false, default: "public"
    end
  end
end
