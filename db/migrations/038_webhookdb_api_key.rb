# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:service_integrations) do
      add_column :webhookdb_api_key, :text, null: true
    end

    alter_table(:idempotencies) do
      add_column :stored_result, :jsonb, null: true
    end
  end
end
