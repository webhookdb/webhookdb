# frozen_string_literal: true

Sequel.migration do
  up do
    alter_table(:oauth_sessions) do
      add_column :token_json, :jsonb
      drop_column :authorization_code
      add_constraint(
        :no_token_json_if_used,
        "NOT (used_at IS NOT NULL AND token_json IS NOT NULL)",
      )
    end
  end

  down do
    alter_table(:oauth_sessions) do
      drop_column :token_json
      add_column :authorization_code, :text
    end
  end
end
