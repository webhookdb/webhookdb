# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:backfill_jobs) do
      add_column :criteria, :jsonb, null: false, default: "{}"
    end
  end
end
