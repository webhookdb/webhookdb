# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:service_integrations) do
      add_index :depends_on_id
      add_index :service_name
    end

    alter_table(:message_deliveries) do
      add_index :soft_deleted_at
    end
  end
end
