# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:organizations) do
      add_column :job_semaphore_size, :int, null: false, default: 10
    end
  end
end
