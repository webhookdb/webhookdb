# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:service_integrations) do
      add_column :skip_webhook_verification, :bool, null: false, default: false
    end
  end
end
