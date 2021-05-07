# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:service_integrations) do
      add_column :api_url, :text, null: false, unique: false, default: ""
    end
  end
end
