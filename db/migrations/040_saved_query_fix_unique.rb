# frozen_string_literal: true

Sequel.migration do
  up do
    alter_table(:saved_queries) do
      drop_constraint(:saved_queries_organization_id_key)
      add_index :organization_id
    end
  end

  down do
    alter_table(:saved_queries) do
      drop_index :organization_id
      add_unique_constraint(:organization_id)
    end
  end
end
