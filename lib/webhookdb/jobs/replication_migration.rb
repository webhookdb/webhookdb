# frozen_string_literal: true

class Webhookdb::Jobs::ReplicationMigration
  include Sidekiq::Worker

  def perform(org_id)
    (org = Webhookdb::Organization[org_id]) or raise "Organization[#{org_id}] does not exist"
    org.migrate_replication_tables
  end
end
