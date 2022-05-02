# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:service_integrations) do
      add_column :data_encryption_secret, :text, null: true
    end
  end
end
