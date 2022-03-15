# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:webhook_subscriptions) do
      add_column :deactivated_at, :timestamptz
    end

    create_table(:webhook_subscription_deliveries) do
      primary_key :id
      timestamptz :created_at, null: false, default: Sequel.function(:now)
      column :attempt_timestamps, "timestamptz[]", null: false, default: []
      column :attempt_http_response_statuses, "smallint[]", null: false, default: []
      jsonb :payload, null: false

      foreign_key :webhook_subscription_id, :webhook_subscriptions, null: false
      index :webhook_subscription_id

      constraint(
        :balanced_attempts,
        Sequel.function(:array_length, :attempt_timestamps,
                        1,) =~ Sequel.function(:array_length, :attempt_http_response_statuses, 1),
      )
    end
  end
end
