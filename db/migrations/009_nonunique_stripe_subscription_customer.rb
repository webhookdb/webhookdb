# frozen_string_literal: true

Sequel.migration do
  up do
    alter_table(:subscriptions) do
      drop_constraint :subscriptions_stripe_customer_id_key
      add_index :stripe_customer_id
    end
  end
  down do
    alter_table(:subscriptions) do
      drop_index :stripe_customer_id
      add_unique_constraint :stripe_customer_id
    end
  end
end
