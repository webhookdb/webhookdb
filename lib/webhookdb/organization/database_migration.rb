# frozen_string_literal: true

class Webhookdb::Organization::DatabaseMigration < Webhookdb::Postgres::Model(:organization_database_migrations)
  class MigrationInProgress < RuntimeError; end
  class MigrationAlreadyFinished < RuntimeError; end

  plugin :timestamps
  plugin :column_encryption do |enc|
    enc.column :source_admin_connection_url
    enc.column :destination_admin_connection_url
  end

  many_to_one :started_by, class: "Webhookdb::Customer"
  many_to_one :organization, class: "Webhookdb::Organization"

  dataset_module do
    def ongoing
      return self.where(finished_at: nil)
    end
  end

  def self.guard_ongoing!(org)
    dbm = self.where(organization: org).ongoing.first
    return if dbm.nil?
    raise MigrationInProgress, "Organization[#{org.id}] already Organization::DatabaseMigration[#{dbm.id}] ongoing"
  end

  def self.enqueue(admin_connection_url_raw:, readonly_connection_url_raw:, public_host:, started_by:, organization:)
    self.guard_ongoing!(organization)
    self.db.transaction do
      dbm = self.create(
        started_by:,
        organization:,
        organization_schema: organization.replication_schema,
        source_admin_connection_url: organization.admin_connection_url_raw,
        destination_admin_connection_url: admin_connection_url_raw,
      )
      organization.update(
        public_host:,
        admin_connection_url_raw:,
        readonly_connection_url_raw:,
      )
      return dbm
    end
  end

  def displaysafe_source_url
    return Webhookdb.displaysafe_url(self.source_admin_connection_url)
  end

  def displaysafe_destination_url
    return Webhookdb.displaysafe_url(self.destination_admin_connection_url)
  end

  def finished?
    return !!self.finished_at
  end

  def migrate
    raise MigrationAlreadyFinished if self.finished?
    self.update(started_at: Time.now) if self.started_at.nil?
    Sequel.connect(self.source_admin_connection_url) do |srcdb|
      Sequel.connect(self.destination_admin_connection_url) do |dstdb|
        self.organization.service_integrations.sort_by(&:id).each do |sint|
          next if sint.id <= self.last_migrated_service_integration_id
          self.migrate_service_integration(sint, srcdb, dstdb)
          self.update(last_migrated_service_integration_id: sint.id, last_migrated_timestamp: nil)
        end
      end
    end
    self.update(finished_at: Time.now)
  end

  # @param [Webhookdb::ServiceIntegration] service_integration
  protected def migrate_service_integration(service_integration, srcdb, dstdb)
    svc = service_integration.service_instance
    # If the service integration was not synced in the old db, skip it
    return unless srcdb.table_exists?(svc.qualified_table_sequel_identifier)
    dstdb << svc.create_table_sql(if_not_exists: true)
    ds = srcdb[svc.qualified_table_sequel_identifier].order(svc.timestamp_column.name)
    (ds = ds.where(Sequel[svc.timestamp_column.name] > self.last_migrated_timestamp)) unless
      self.last_migrated_timestamp.nil?
    chunksize = Webhookdb::Organization.database_migration_page_size
    chunk = []
    ds.paged_each(rows_per_fetch: chunksize, hold: true) do |row|
      chunk << row
      if chunk.size >= chunksize
        self.upsert_chunk(service_integration, dstdb, chunk)
        chunk.clear
      end
    end
    self.upsert_chunk(service_integration, dstdb, chunk)
  end

  # @param [Webhookdb::ServiceIntegration] service_integration
  protected def upsert_chunk(service_integration, dstdb, chunk)
    return if chunk.empty?
    svc = service_integration.service_instance
    chunk.each { |h| h.delete(svc.primary_key_column.name) }
    tscol = svc.timestamp_column.name
    dstdb[svc.qualified_table_sequel_identifier].
      insert_conflict(
        target: svc.remote_key_column.name,
        update_where: svc._update_where_expr,
      ).multi_insert(chunk)
    self.update(last_migrated_timestamp: chunk.last[tscol])
  end

  def finish(now: Time.now)
    self.update(
      finished_at: now,
      source_admin_connection_url: "",
      destination_admin_connection_url: "",
    )
    return self
  end
end
