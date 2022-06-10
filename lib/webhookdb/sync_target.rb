# frozen_string_literal: true

# Support exporting WebhookDB data into external services,
# such as another Postgres instance or data warehouse (Snowflake, etc).
#
# At a high level, the way sync targets work are:
# - User uses the CLI to register a sync target for a specific integration
#   using a database connection string for a supported db (ie, postgres://).
# - They include a period (how often it is synced), and an optional schema and table
#   (if not used, we'll use the default schema, and the service integration table name).
# - Every minute or so, we look for sync targets that are "due" and enqueue a sync for them.
#   Customers can enqueue their own sync request; but it cannot run more than the
#   minimum allowed sync time.
#
# For the sync logic itself, see +run_sync+.
#
class Webhookdb::SyncTarget < Webhookdb::Postgres::Model(:sync_targets)
  include Appydays::Configurable

  class SyncInProgress < RuntimeError; end

  configurable(:sync_target) do
    # Allow installs to set this much lower if they want a faster sync,
    # but something higher is better as a default.
    setting :min_period_seconds, 10.minutes.to_i
    setting :max_period_seconds, 24.hours.to_i
    # Sync targets without an explicit schema set
    # will add tables into this schema. We use public by default
    # since it's convenient, but for tests, it could cause conflicts
    # so something else is set instead.
    setting :default_schema, "public"

    after_configured do
      if Webhookdb::RACK_ENV == "test"
        safename = ENV["USER"].gsub(/[^A-Za-z]/, "")
        self.default_schema = "synctest_#{safename}"
      end
    end
  end

  def self.valid_period
    return self.min_period_seconds..self.max_period_seconds
  end

  plugin :timestamps
  plugin :column_encryption do |enc|
    enc.column :connection_url
  end

  # Eventually we will allow full sync of an org's data,
  # but for now let's link to just a service integration
  many_to_one :service_integration, class: Webhookdb::ServiceIntegration
  many_to_one :created_by, class: Webhookdb::Customer

  dataset_module do
    def due_for_sync(as_of:)
      never_synced = Sequel[last_synced_at: nil]
      next_due_at = Sequel[:last_synced_at] + (Sequel.lit("INTERVAL '1 second'") * Sequel[:period_seconds])
      due_before_now = next_due_at <= as_of
      return self.where(never_synced | due_before_now)
    end
  end

  def next_scheduled_sync(now:)
    return self.next_sync(self.period_seconds, now)
  end

  def next_possible_sync(now:)
    return self.next_sync(self.class.min_period_seconds, now)
  end

  protected def next_sync(period, now)
    return now if self.last_synced_at.nil?
    return [now, self.last_synced_at + period].max
  end

  # Running a sync involves some work we always do (export, transform),
  # and then work that varies per-adapter (load).
  #
  # - Lock this row to make sure we never sync the same service integer
  #   at the same time. We early out if the lock is held since it can take a while to sync.
  # - Ensure the sync target table exists and has the right schema.
  #   In general we do NOT create indices for the target table;
  #   since this table is for a client's data warehouse, we assume they will optimize it as needed.
  #   The only exception is the unique constraint for the remote key column.
  # - Select rows created/updated since our last update in our 'source' database.
  # - Write them to disk into a CSV file.
  # - Pass this CSV file to the proper sync target adapter.
  # - For example, the PG sync target will:
  #   - Create a temp table in the target database, using the schema from the sync target table.
  #   - Load the data into that temp table.
  #   - Insert rows into the target table temp table rows that do not appear in the target table.
  #   - Update rows in the target table temp table rows that already appear in the target table.
  # - The snowflake sync target will:
  #   - PUT the CSV file into the stage for the table.
  #   - Otherwise the logic is the same as PG: create a temp table and COPY INTO from the CSV.
  #   - Purge the staged file.
  def run_sync(at:)
    tempfile = nil
    self.db.transaction do
      available = self.class.dataset.where(id: self.id).lock_style("FOR UPDATE SKIP LOCKED").first
      raise SyncInProgress, "SyncTarget[#{self.id}] is already being synced" if available.nil?
      self.lock!
      svc = self.service_integration.service_instance
      schema_name = self.schema.present? ? self.schema : self.class.default_schema
      table_name = self.table.present? ? self.table : self.service_integration.table_name
      adapter = self.adapter
      schema = Webhookdb::DBAdapter::Schema.new(name: schema_name.to_sym)
      table = Webhookdb::DBAdapter::Table.new(name: table_name.to_sym, schema:)

      schema_lines = []
      schema_lines << adapter.create_schema_sql(table.schema, if_not_exists: true)
      schema_lines << adapter.create_table_sql(
        table,
        [svc.primary_key_column, svc.remote_key_column],
        if_not_exists: true,
      )
      (svc.denormalized_columns + [svc.data_column]).each do |col|
        schema_lines << adapter.add_column_sql(table, col, if_not_exists: true)
      end
      adapter_conn = adapter.connection(self.connection_url)
      adapter_conn.execute(schema_lines.join(";\n") + ";")
      tempfile = Tempfile.new("whdbsyncout-#{self.id}")
      tscol = Sequel[svc.timestamp_column.name]
      svc.readonly_dataset do |ds|
        tscond = (tscol <= at)
        self.last_synced_at && (tscond &= (tscol >= self.last_synced_at))
        ds = ds.where(tscond)
        ds.db.copy_table(ds, options: "DELIMITER ',', HEADER true, FORMAT csv") do |row|
          tempfile.write(row)
        end
      end
      tempfile.rewind
      adapter.merge_from_csv(
        adapter_conn,
        tempfile,
        table,
        svc.primary_key_column,
        [svc.primary_key_column, svc.remote_key_column] + svc.denormalized_columns + [svc.data_column],
      )
      self.update(last_synced_at: at)
    ensure
      tempfile&.unlink
    end
  end

  def adapter
    return Webhookdb::DBAdapter.adapter(self.connection_url)
  end

  def adapter_connection
    return self.adapter.connection(self.connection_url)
  end

  def displaysafe_connection_url
    u = URI(self.connection_url)
    u.user = "***"
    u.password = "***"
    return u.to_s
  end

  def associated_type
    # Eventually we need to support orgs
    return "service_integration"
  end

  def associated_id
    # Eventually we need to support orgs
    return self.service_integration.opaque_id
  end

  def before_create
    self[:opaque_id] ||= Webhookdb::Id.new_opaque_id("syt")
  end

  # @!attribute service_integration
  #   @return [Webhookdb::ServiceIntegration]

  # @!attribute connection_url
  #   @return [String]
end
