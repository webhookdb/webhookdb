# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:service_integrations) do
      add_column :partition_value, :int, default: 0, null: false
    end
  end
end
