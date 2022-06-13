# frozen_string_literal: true

Sequel.migration do
  up do
    alter_table(:organizations) do
      set_column_default(:replication_schema, nil)
    end
  end
  down do
    alter_table(:organizations) do
      set_column_default(:replication_schema, "public")
    end
  end
end
