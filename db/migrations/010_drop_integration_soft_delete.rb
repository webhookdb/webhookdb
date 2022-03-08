# frozen_string_literal: true

Sequel.migration do
  up do
    alter_table(:service_integrations) do
      drop_column :soft_deleted_at
    end
  end
  down do
    alter_table(:subscriptions) do
      add_column :soft_deleted_at, :timestamptz
    end
  end
end
