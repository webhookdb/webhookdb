# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:organizations) do
      primary_key :id
      timestamptz :created_at, null: false, default: Sequel.function(:now)
      timestamptz :updated_at
      timestamptz :soft_deleted_at

      text :name, null: false, unique: true

      text :readonly_connection_url
      text :readwrite_connection_url
      text :admin_connection_url
    end

    create_table(:service_integrations) do
      primary_key :id
      timestamptz :created_at, null: false, default: Sequel.function(:now)
      timestamptz :updated_at
      timestamptz :soft_deleted_at

      foreign_key :organization_id, :organizations, null: false
      text :opaque_id, null: false, unique: true
      text :service_name, null: false
      text :webhook_secret, default: ""
      text :table_name, null: false
      index [:organization_id, :table_name], name: :unique_tablename_in_org, unique: true
    end

    create_table(:customers) do
      primary_key :id
      timestamptz :created_at, null: false, default: Sequel.function(:now)
      timestamptz :updated_at
      timestamptz :soft_deleted_at

      text :password_digest, null: false

      citext :email, null: false, unique: true
      constraint(:lowercase_nospace_email, Sequel[:email] => Sequel.function(:btrim, Sequel.function(:lower, :email)))
      timestamptz :email_verified_at

      text :phone, null: false, unique: true
      constraint(:numeric_phone, Sequel.lit("phone ~ '^[0-9]{11,15}$'"))
      timestamptz :phone_verified_at

      text :first_name, null: false, default: ""
      text :last_name, null: false, default: ""
      text :note, null: false, default: ""
      text :timezone, null: false, default: "America/Los_Angeles"

      foreign_key :organization_id, :organizations, null: false
    end

    create_table(:customer_reset_codes) do
      primary_key :id
      timestamptz :created_at, null: false, default: Sequel.function(:now)
      timestamptz :updated_at

      text :transport, null: false
      text :token, null: false
      boolean :used, null: false, default: false
      timestamptz :expire_at, null: false

      foreign_key :customer_id, :customers, null: false, on_delete: :cascade
      index :customer_id
    end

    create_table(:idempotencies) do
      primary_key :id
      timestamptz :created_at, null: false, default: Sequel.function(:now)
      timestamptz :updated_at
      timestamptz :last_run
      text :key, unique: true
    end

    create_table(:roles) do
      primary_key :id
      text :name, null: false, unique: true
    end

    create_join_table({role_id: :roles, customer_id: :customers}, name: :roles_customers)

    create_table(:message_deliveries) do
      primary_key :id
      timestamptz :created_at, null: false, default: Sequel.function(:now)
      timestamptz :updated_at
      text :template, null: false
      text :transport_type, null: false
      text :transport_service, null: false
      text :transport_message_id, unique: true
      timestamptz :sent_at
      text :to, null: false
      foreign_key :recipient_id, :customers, on_delete: :set_null
      jsonb :extra_fields, null: false, default: "{}"
      timestamptz :soft_deleted_at
      index :recipient_id
      index :sent_at
    end

    create_table(:message_bodies) do
      primary_key :id
      text :content, null: false
      text :mediatype, null: false
      foreign_key :delivery_id, :message_deliveries, null: false, on_delete: :cascade
      index :delivery_id
    end
  end
end
