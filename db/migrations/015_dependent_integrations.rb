# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:service_integrations) do
      add_foreign_key :depends_on_id, :service_integrations, on_delete: :restrict
    end
  end
end
