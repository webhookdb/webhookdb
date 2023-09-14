# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:oauth_sessions) do
      add_column :used_at, :timestamptz
    end
  end
end
