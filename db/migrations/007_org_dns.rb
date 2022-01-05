# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:organizations) do
      add_column :public_host, :text, null: false, default: ""
      add_column :cloudflare_dns_record_json, :jsonb, null: false, default: "{}"
      rename_column :readonly_connection_url, :readonly_connection_url_raw
      rename_column :admin_connection_url, :admin_connection_url_raw
    end
  end
end
