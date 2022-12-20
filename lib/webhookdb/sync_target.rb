# frozen_string_literal: true

require "sequel/database"
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
  include Webhookdb::Dbutil

  class SyncInProgress < StandardError; end

  configurable(:sync_target) do
    # Allow installs to set this much lower if they want a faster sync,
    # but something higher is better as a default.
    # Can be overridden per-organization.
    setting :default_min_period_seconds, 10.minutes.to_i
    setting :max_period_seconds, 24.hours.to_i
    # Sync targets without an explicit schema set
    # will add tables into this schema. We use public by default
    # since it's convenient, but for tests, it could cause conflicts
    # so something else is set instead.
    setting :default_schema, "public"
    # If we want to sync to a localhost url for development purposes,
    # we must allow sync targets to use http urls. This should only
    # be used internally, and never in production.
    setting :allow_http, false

    after_configured do
      if Webhookdb::RACK_ENV == "test"
        safename = ENV["USER"].gsub(/[^A-Za-z]/, "")
        self.default_schema = "synctest_#{safename}"
      end
    end
  end

  def self.valid_period(beginval)
    return beginval..self.max_period_seconds
  end

  def self.valid_period_for(org)
    return self.valid_period(org.minimum_sync_seconds)
  end

  def self.default_valid_period
    return self.valid_period(Webhookdb::SyncTarget.default_min_period_seconds)
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

  def self.validate_url(s)
    begin
      url = URI(s)
    rescue URI::InvalidURIError
      return "The URL is not valid"
    end
    # rubocop:disable Layout/LineLength
    not_supported_msg = "The '#{url.scheme}' protocol is not supported. Supported protocols are: postgres, snowflake, https"
    # rubocop:enable Layout/LineLength
    case url.scheme
      when "postgres", "snowflake"
        return nil if url.user.present? && url.password.present?
        url.user = "user"
        url.password = "pass"
        return "Database URLs must include a username and password, like '#{url}'"
      when "https"
        return nil if url.user.present? || url.password.present?
        url.user = "user"
        url.password = "pass"
        return "https urls must include a Basic Auth username and/or password, like '#{url}'"
      when "http"
        # http behavior should be identical to https scheme, except that it should not be supported
        # unless configuration allows it
        return not_supported_msg unless Webhookdb::SyncTarget.allow_http
        return nil if url.user.present? || url.password.present?
        url.user = "user"
        url.password = "pass"
        return "https urls must include a Basic Auth username and/or password, like '#{url}'"
      else
        return not_supported_msg
    end
  end

  def next_scheduled_sync(now:)
    return self.next_sync(self.period_seconds, now)
  end

  def next_possible_sync(now:)
    return self.next_sync(self.organization.minimum_sync_seconds, now)
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

      # Note that http links are not secure and should only be used for development purposes
      return self._run_sync_http(at) if self.connection_url.start_with?("https://", "http://")

      svc = self.service_integration.replicator
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
      schema_expr = schema_lines.join(";\n") + ";"
      if schema_expr != self.last_applied_schema
        adapter_conn.execute(schema_expr)
        self.update(last_applied_schema: schema_expr)
      end
      tempfile = Tempfile.new("whdbsyncout-#{self.id}")
      self._dataset_to_sync(at) do |ds|
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

  def _run_sync_http(at)
    self._dataset_to_sync(at) do |ds|
      chunk = []
      ds.paged_each(rows_per_fetch: self.page_size) do |row|
        chunk << row
        self._flush_http_chunk(at, chunk) if chunk.size >= self.page_size
      end
      self._flush_http_chunk(at, chunk) unless chunk.empty?
    end
    self.update(last_synced_at: at)
  end

  def _flush_http_chunk(at, chunk)
    sint = self.service_integration
    body = {
      rows: chunk,
      integration_id: sint.opaque_id,
      integration_service: sint.service_name,
      table: sint.table_name,
      sync_timestamp: at,
    }
    cleanurl, authparams = Webhookdb::Http.extract_url_auth(self.connection_url)
    Webhookdb::Http.post(
      cleanurl,
      body,
      timeout: sint.organization.sync_target_timeout,
      logger: self.logger,
      basic_auth: authparams,
    )
    chunk.clear
  end

  def _dataset_to_sync(at)
    svc = self.service_integration.replicator
    tscol = Sequel[svc.timestamp_column.name]
    svc.readonly_dataset do |ds|
      tscond = (tscol <= at)
      self.last_synced_at && (tscond &= (tscol >= self.last_synced_at))
      ds = ds.where(tscond)
      yield(ds)
    end
  end

  def adapter
    return Webhookdb::DBAdapter.adapter(self.connection_url)
  end

  def adapter_connection
    return self.adapter.connection(self.connection_url)
  end

  def displaysafe_connection_url
    return displaysafe_url(self.connection_url)
  end

  def associated_type
    # Eventually we need to support orgs
    return "service_integration"
  end

  def associated_id
    # Eventually we need to support orgs
    return self.service_integration.opaque_id
  end

  def organization
    return self.service_integration.organization
  end

  def before_create
    self[:opaque_id] ||= Webhookdb::Id.new_opaque_id("syt")
  end

  # @!attribute service_integration
  #   @return [Webhookdb::ServiceIntegration]

  # @!attribute connection_url
  #   @return [String]
end

# Table: sync_targets
# --------------------------------------------------------------------------------------------------------------------------
# Columns:
#  id                     | integer                  | PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY
#  created_at             | timestamp with time zone | NOT NULL DEFAULT now()
#  updated_at             | timestamp with time zone |
#  opaque_id              | text                     | NOT NULL
#  service_integration_id | integer                  | NOT NULL
#  created_by_id          | integer                  |
#  period_seconds         | integer                  | NOT NULL
#  connection_url         | text                     | NOT NULL
#  schema                 | text                     | NOT NULL DEFAULT ''::text
#  table                  | text                     | NOT NULL DEFAULT ''::text
#  last_synced_at         | timestamp with time zone |
#  last_applied_schema    | text                     | NOT NULL DEFAULT ''::text
# Indexes:
#  sync_targets_pkey                         | PRIMARY KEY btree (id)
#  sync_targets_opaque_id_key                | UNIQUE btree (opaque_id)
#  sync_targets_last_synced_at_index         | btree (last_synced_at)
#  sync_targets_service_integration_id_index | btree (service_integration_id)
# Foreign key constraints:
#  sync_targets_created_by_id_fkey          | (created_by_id) REFERENCES customers(id) ON DELETE SET NULL
#  sync_targets_service_integration_id_fkey | (service_integration_id) REFERENCES service_integrations(id) ON DELETE CASCADE
# --------------------------------------------------------------------------------------------------------------------------
