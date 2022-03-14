# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:webhook_subscriptions) do
      add_foreign_key :created_by_id, :customers
    end
  end
end
