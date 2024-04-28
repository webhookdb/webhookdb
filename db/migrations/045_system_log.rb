# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:system_log_events) do
      primary_key :id, type: :bigserial
      timestamptz :at, null: false, default: Sequel.function(:now), index: true
      text :title, null: false, default: ""
      text :body, null: false, default: ""
      text :link, null: false, default: ""
      foreign_key :actor_id, :customers
      column :text_search, :tsvector
    end
  end
end
