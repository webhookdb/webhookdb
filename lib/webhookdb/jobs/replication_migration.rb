# frozen_string_literal: true

# See Organization::enqueue_migrate_all_replication_tables for more info.
class Webhookdb::Jobs::ReplicationMigration
  extend Webhookdb::Async::Job

  def perform(org_id, target_release_created_at)
    (org = Webhookdb::Organization[org_id]) or raise "Organization[#{org_id}] does not exist"
    target_rca = Time.parse(target_release_created_at)
    current_rca = Time.parse(Webhookdb::RELEASE_CREATED_AT)
    self.set_job_tags(organization_id: org_id, target_release_created_at:)
    if target_rca == current_rca
      self.class.migrate_org(org)
      self.set_job_tags(result: "ran_replication_migration_job")
    elsif target_rca > current_rca
      self.class.perform_in(1, org_id, target_release_created_at)
      self.set_job_tags(result: "reenqueued_replication_migration_job")
    else
      self.set_job_tags(result: "stale_replication_migration_job")
    end
  end

  # To make mocking easier.
  def self.migrate_org(org)
    org.migrate_replication_tables
  end
end
