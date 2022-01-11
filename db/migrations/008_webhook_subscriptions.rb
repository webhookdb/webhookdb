# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:webhook_subscriptions) do
      primary_key :id
      text :deliver_to_url, null: false
      text :webhook_secret, null: false
      text :opaque_id, null: false, unique: true
      foreign_key :service_integration_id, :service_integrations
      foreign_key :organization_id, :organizations

      constraint(:service_integration_or_org) do
        ((service_integration_id =~ nil) & (organization_id !~ nil)) |
          ((service_integration_id !~ nil) & (organization_id =~ nil))
      end
    end
  end
end
