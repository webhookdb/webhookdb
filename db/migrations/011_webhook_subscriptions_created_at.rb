# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:webhook_subscriptions) do
      add_column :created_at, :timestamptz, null: false, default: Sequel.function(:now)
      add_column :updated_at, :timestamptz
    end
  end
end
