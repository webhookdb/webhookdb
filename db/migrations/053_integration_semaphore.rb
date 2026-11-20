# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:service_integrations) do
      add_column :integration_job_semaphore_size, :int, null: false, default: 0
    end
    alter_table(:organizations) do
      rename_column :job_semaphore_size, :organization_job_semaphore_size
    end
  end
end
