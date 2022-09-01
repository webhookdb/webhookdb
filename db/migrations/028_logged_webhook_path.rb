# frozen_string_literal: true

Sequel.migration do
  up do
    alter_table(:logged_webhooks) do
      add_column :request_method, :text, null: true
      add_column :request_path, :text, null: true
    end
    from(:logged_webhooks).update(
      request_method: "POST",
      request_path: Sequel.function(:concat, "/v1/service_integrations/", :service_integration_opaque_id),
    )
    alter_table(:logged_webhooks) do
      set_column_not_null :request_method
      set_column_not_null :request_path
    end
  end
  down do
    alter_table(:logged_webhooks) do
      drop_column :request_method
      drop_column :request_path
    end
  end
end
