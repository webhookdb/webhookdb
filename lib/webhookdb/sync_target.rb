# frozen_string_literal: true

require "sequel/advisory_lock"
require "sequel/database"

require "webhookdb/concurrent"
require "webhookdb/jobs/sync_target_run_sync"

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

  class Deleted < Webhookdb::WebhookdbError; end
  class InvalidConnection < Webhookdb::WebhookdbError; end
  class SyncInProgress < Webhookdb::WebhookdbError; end

  # Advisory locks for sync targets use this as the first int, and the id as the second.
  ADVISORY_LOCK_KEYSPACE = 2_000_000_000

  HTTP_VERIFY_TIMEOUT = 3
  DB_VERIFY_TIMEOUT = 2000
  DB_VERIFY_STATEMENT = "SELECT 1"
  RAND = Random.new
  MAX_STATS = 200

  configurable(:sync_target) do
    # Allow installs to set this much lower if they want a faster sync.
    # On production we use 1 minute as a default since it's faster than the replication delay
    # of similar services but not fast enough to discourage self-hosting (which can be immediate).
    # We have 10 minutes here for test compatibility (API endpoints read and store this when they are built).
    # Can be overridden per-organization.
    setting :default_min_period_seconds, 10.minutes.to_i
    setting :max_period_seconds, 24.hours.to_i
    # How many items sent in each POST for http sync targets.
    setting :default_page_size, 200
    # Sync targets without an explicit schema set
    # will add tables into this schema. We use public by default
    # since it's convenient, but for tests, it could cause conflicts
    # so something else is set instead.
    setting :default_schema, "public"
    # If we want to sync to a localhost url for development purposes,
    # we must allow sync targets to use http urls. This should only
    # be used internally, and never in production.
    setting :allow_http, false
    # Syncing may require serverside cursors, which open a transaction.
    # To avoid long-lived transactions, any sync which has a transaction,
    # and goes on longer than +max_transaction_seconds+,
    # will 'soft abort' the sync and reschedule itself to continue
    # using a new transaction.
    setting :max_transaction_seconds, 10.minutes.to_i

    after_configured do
      if Webhookdb::RACK_ENV == "test"
        safename = ENV.fetch("USER", "root").gsub(/[^A-Za-z]/, "")
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
  plugin :text_searchable, terms: [:service_integration, :created_by]
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
      # Use 'last_synced_at <= (now - internal)' rather than 'last_synced_at + interval <= now'
      # so we can use the last_synced_at index.
      cutoff = (Sequel[as_of].cast("TIMESTAMPTZ") - (Sequel.lit("INTERVAL '1 second'") * Sequel[:period_seconds]))
      due_before_now = Sequel[:last_synced_at] <= cutoff
      return self.where(never_synced | due_before_now)
    end
  end

  def http?
    url = URI(self.connection_url)
    return true if ["http", "https"].include?(url.scheme)
    return false
  end

  def db?
    return !self.http?
  end

  def self.validate_db_url(s)
    begin
      url = URI(s)
    rescue URI::InvalidURIError
      return "That's not a valid URL."
    end
    protocols = ["postgres", "snowflake"]
    unless protocols.include?(url.scheme)
      protostr = protocols.join(", ")
      # rubocop:disable Layout/LineLength
      msg = "The '#{url.scheme}' protocol is not supported for database sync targets. Supported protocols are: #{protostr}."
      # rubocop:enable Layout/LineLength
      return msg
    end
    return nil
  end

  def self.validate_http_url(s)
    begin
      url = URI(s)
    rescue URI::InvalidURIError
      return "That's not a valid URL."
    end
    case url.scheme
      when "https"
        return nil if url.user.present? || url.password.present?
        url.user = "user"
        url.password = "pass"
        return "https urls must include a Basic Auth username and/or password, like '#{url}'"
      when "http"
        # http does not require a username/pass since it's only for internal use.
        return Webhookdb::SyncTarget.allow_http ? nil : "Url must be https, not http."
      else
        return "Must be an https url."
    end
  end

  def self.verify_db_connection(url)
    adapter = Webhookdb::DBAdapter.adapter(url)
    begin
      adapter.verify_connection(url, timeout: DB_VERIFY_TIMEOUT, statement: DB_VERIFY_STATEMENT)
    rescue StandardError => e
      # noinspection RailsParamDefResolve
      msg = e.try(:wrapped_exception).try(:to_s) || e.to_s
      raise InvalidConnection, "Could not SELECT 1: #{msg.strip}"
    end
  end

  def self.verify_http_connection(url)
    cleanurl, authparams = Webhookdb::Http.extract_url_auth(url)
    body = {
      rows: [],
      integration_id: "svi_test",
      integration_service: "httpsync_test",
      table: "test",
    }
    begin
      Webhookdb::Http.post(
        cleanurl,
        body,
        logger: self.logger,
        basic_auth: authparams,
        timeout: HTTP_VERIFY_TIMEOUT,
        follow_redirects: true,
      )
    rescue StandardError => e
      raise InvalidConnection, "POST to #{cleanurl} failed: #{e.message}" if
        e.is_a?(Webhookdb::Http::Error) || self.transport_error?(e)
      raise
    end
  end

  # Return true if the given error is considered a 'transport' error,
  # like a timeout, socket error, dns error, etc.
  # This isn't a consistent class type.
  def self.transport_error?(e)
    return true if e.is_a?(Timeout::Error)
    return true if e.is_a?(SocketError)
    return true if e.is_a?(OpenSSL::SSL::SSLError)
    # SystemCallError are Errno errors, we can get them when the url no longer resolves.
    return true if e.is_a?(SystemCallError)
    # Socket::ResolutionError is an error but I guess it's defined in C and we can't raise it in tests.
    # Anything with an error_code assume is some transport-level issue and treat it as a connection issue,
    # not a coding issue.
    return true if e.respond_to?(:error_code)
    return false
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

  # Return the jitter used for enqueing the next sync of the job.
  # It should never be more than 20 seconds,
  # nor should it be more than 1/4 of the total period,
  # since it needs to run at a reasonably predictable time.
  # Jitter is always >= 1, since it is helpful to be able to assert it
  # will always be in the future.
  def jitter
    max_jitter = [20, self.period_seconds / 4].min
    max_jitter = [1, max_jitter].max
    return RAND.rand(1..max_jitter)
  end

  # @return [ActiveSupport::Duration,Integer]
  def latency(now: Time.now)
    return 0 if self.last_synced_at.nil?
    return 0 if self.last_synced_at > now
    return now - self.last_synced_at
  end

  # Running a sync involves some work we always do (export, transform),
  # and then work that varies per-adapter (load).
  #
  # First, we lock using an advisory lock to make sure we never sync the same sync target
  # concurrently. It can cause correctness and performance issues.
  # Raise a +SyncInProgress+ error if we're currently syncing.
  #
  # If the sync target is against an HTTP URL, see +_run_http_sync+.
  #
  # If the sync target is a database connection:
  #
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
  #
  # @param now [Time] The current time. Rows that were updated <= to 'now', and >= the 'last updated' timestamp,
  # will be synced.
  def run_sync(now:)
    return false if self.disabled
    ran = false
    # Take the advisory lock with a separate connection. This seems to be pretty important-
    # it's possible that (for reasons not clear at this time) using the standard connection pool
    # results in the lock being held since the session remains open for a while on the worker.
    # Opening a separate connection ensures that, once this method exits, the lock will be released
    # since the session will be ended.
    Webhookdb::Dbutil.borrow_conn(Webhookdb::Postgres::Model.uri) do |db|
      self.advisory_lock(db).with_lock? do
        self.logger.info "starting_sync"
        routine = if self.connection_url.start_with?("https://", "http://")
                    # Note that http links are not secure and should only be used for development purposes
                    HttpRoutine.new(now, self)
        else
          DatabaseRoutine.new(now, self)
        end
        routine.run
        ran = true
      end
    end
    raise SyncInProgress, "SyncTarget[#{self.id}] is already being synced" unless ran
  end

  # @return [Sequel::AdvisoryLock]
  def advisory_lock(db)
    return Sequel::AdvisoryLock.new(db, ADVISORY_LOCK_KEYSPACE, self.id)
  end

  def displaysafe_connection_url
    return displaysafe_url(self.connection_url)
  end

  def log_tags
    return {
      sync_target_id: self.id,
      sync_target_connection_url: self.displaysafe_connection_url,
      service_integration_id: self.service_integration_id,
      service_integration_service: self.service_integration.service_name,
      service_integration_table: self.service_integration.table_name,
    }
  end

  # @return [String]
  def associated_type
    # Eventually we need to support orgs
    return "service_integration"
  end

  # @return [String]
  def associated_id
    # Eventually we need to support orgs
    return self.service_integration.opaque_id
  end

  def associated_object_display
    return "#{self.service_integration.opaque_id}/#{self.service_integration.table_name}"
  end

  # @return [String]
  def schema_and_table_string
    schema_name = self.schema.present? ? self.schema : self.class.default_schema
    table_name = self.table.present? ? self.table : self.service_integration.table_name
    return "#{schema_name}.#{table_name}"
  end

  # :section: Stats

  def add_sync_stat(call_start:, remote_start:, exception: nil, response_status: nil)
    now = Time.now
    stat = {
      "t" => s2ms(now),
      "dr" => s2ms(now - remote_start),
      "dc" => s2ms(now - call_start),
    }
    stat["e"] = exception.class.name if exception
    stat["rs"] = response_status unless response_status.nil?
    stats = self.sync_stats
    stats.prepend(stat)
    stats.pop if stats.size > MAX_STATS
    self.will_change_column(:sync_stats)
  end

  protected def s2ms(t) = (t.to_f * 1000).to_i
  protected def ms2s(ms) = ms / 1000.0

  def sync_stat_summary
    return {} if self.sync_stats.empty?
    earliest = self.sync_stats.last
    latest = self.sync_stats.first

    avg_remote_latency = 0
    avg_call_latency = 0
    errors = 0
    self.sync_stats.each do |st|
      avg_remote_latency += st["dr"] if st["dr"]
      avg_call_latency += st["dc"] if st["dc"]
      errors += 1 if st["e"] || st["rs"]
    end
    avg_remote_latency = ms2s(avg_remote_latency / self.sync_stats.size).round(2)
    avg_call_latency = ms2s(avg_call_latency / self.sync_stats.size).round(2)
    avg_calls_minute = self._stat_average_calls_per_minute.round(2)
    avg_rows_minute = (avg_calls_minute * self.page_size).to_i
    return {
      earliest: earliest["t"] ? Time.at(ms2s(earliest["t"]).to_i) : Time.at(0),
      latest: latest["t"] ? Time.at(ms2s(latest["t"]).to_i) : Time.at(0),
      avg_remote_latency:,
      avg_call_latency:,
      avg_rows_minute:,
      avg_calls_minute:,
      errors:,
    }
  end

  # See how many calls we've made over the lifetime of the sync stats,
  # and average to a minute.
  def _stat_average_calls_per_minute
    start_timespan = Time.now.to_f - ms2s(self.sync_stats.last["t"])
    return 0 if start_timespan.zero?
    per_second = self.sync_stats.count / start_timespan.to_f
    per_minute = per_second * 60
    return per_minute
  end

  # @return [Webhookdb::Organization]
  def organization
    return self.service_integration.organization
  end

  def before_validation
    self.page_size ||= Webhookdb::SyncTarget.default_page_size
    super
  end

  def before_create
    self[:opaque_id] ||= Webhookdb::Id.new_opaque_id("syt")
  end

  # @!attribute service_integration
  #   @return [Webhookdb::ServiceIntegration]

  # @!attribute connection_url
  #   @return [String]

  # @!attribute last_synced_at
  #   @return [Time]

  class Routine
    attr_reader :now, :sync_target, :replicator, :timestamp_expr

    def initialize(now, sync_target)
      @now = now
      @sync_target = sync_target
      @last_synced_at = sync_target.last_synced_at
      @replicator = sync_target.service_integration.replicator
      @timestamp_expr = Sequel[@replicator.timestamp_column.name]
    end

    def run = raise NotImplementedError

    # Get the dataset of rows that need to be synced.
    # Note that there are a couple race conditions here.
    # First, those in https://github.com/webhookdb/webhookdb/issues/571.
    # There is also the condition that we could send the same row
    # multiple times when the row timestamp is set to last_synced_at but
    # it wasn't in the last sync; however that is likely not a big problem
    # since clients need to handle updates in any case.
    def dataset_to_sync
      # Use admin dataset, since the client could be using all their readonly conns.
      @replicator.admin_dataset do |ds|
        # Find rows updated before we started
        tscond = (@timestamp_expr <= @now)
        # Find rows updated after the last sync was run
        @last_synced_at && (tscond &= (@timestamp_expr >= @last_synced_at))
        ds = ds.where(tscond)
        # We want to paginate from oldest to newest
        ds = ds.order(@timestamp_expr)
        yield(ds)
      end
    end

    def perform_db_op(&)
      yield
    rescue Sequel::NoExistingObject => e
      raise Webhookdb::SyncTarget::Deleted, e
    end

    def record(last_synced_at)
      self.perform_db_op do
        self.sync_target.update(last_synced_at:)
      end
    end

    # Wrap a remote call and record a stat on finish.
    # +call_start+ should be when the current call/page began syncing.
    # The block is assumed to be a DB or HTTP callout.
    def with_stat(call_start, &)
      remote_start = Time.now
      begin
        yield
        self.sync_target.add_sync_stat(call_start:, remote_start:)
      rescue Webhookdb::Http::Error => e
        self.sync_target.add_sync_stat(call_start:, remote_start:, response_status: e.status)
        raise
      rescue StandardError => e
        self.sync_target.add_sync_stat(call_start:, remote_start:, exception: e)
        raise
      end
    end

    def to_ms(t)
      return (t.to_f * 1000).to_i
    end
  end

  class HttpRoutine < Routine
    def initialize(*)
      super
      @inflight_timestamps = []
      @cleanurl, @authparams = Webhookdb::Http.extract_url_auth(self.sync_target.connection_url)
      @threadpool = if self.sync_target.parallelism.zero?
                      Webhookdb::Concurrent::SerialPool.new
        else
          Webhookdb::Concurrent::ParallelizedPool.new(self.sync_target.parallelism)
      end
      @mutex = Thread::Mutex.new
    end

    def run
      timeout_at = Time.now + Webhookdb::SyncTarget.max_transaction_seconds
      page_size = self.sync_target.page_size
      sync_result = :complete
      self.dataset_to_sync do |ds|
        chunk = []
        cursor_name = "synctarget_#{self.sync_target.service_integration.service_name}_#{self.sync_target.id}_cursor"
        chunk_start = Time.now
        ds.paged_each(rows_per_fetch: page_size, cursor_name:) do |row|
          chunk << row
          if chunk.size >= page_size
            # Do not share chunks across threads
            self._flush_http_chunk(chunk_start, chunk.dup)
            chunk.clear
            chunk_start = Time.now
            if Time.now >= timeout_at && Thread.current[:sidekiq_context]
              # If we've hit the timeout, stop any further syncing
              sync_result = :timeout
              break
            end
          end
        end
        self._flush_http_chunk(chunk_start, chunk) unless chunk.empty?
        @threadpool.join
        case sync_result
          when :timeout
            # If the sync timed out, use the last recorded sync timestamp,
            # and re-enqueue the job, so the sync will pick up where it left off.
            self.sync_target.logger.info("sync_target_transaction_timeout", self.sync_target.log_tags)
            Webhookdb::Jobs::SyncTargetRunSync.perform_async(self.sync_target.id)
          else
            # The sync completed normally.
            # Save 'now' as the timestamp, rather than the last updated row.
            # This is important because other we'd keep trying to sync the last row synced.
            self.record(self.now)
        end
      end
    rescue Webhookdb::Concurrent::Timeout => e
      # This should never really happen, but it does, so record it while we debug it.
      self.perform_db_op do
        self.sync_target.save_changes
      end
      self.sync_target.logger.error("sync_target_pool_timeout_error", self.sync_target.log_tags, e)
    rescue StandardError => e
      # Errors talking to the http server are handled well so no need to re-raise.
      # We already committed the last page that was successful,
      # so we can just stop syncing at this point to try again later.
      raise e unless e.is_a?(Webhookdb::Http::Error) || Webhookdb::SyncTarget.transport_error?(e)
      self.perform_db_op do
        # Save any outstanding stats.
        self.sync_target.save_changes
      end
      # Don't spam our logs with downstream errors
      idem_key = "sync_target_http_error-#{self.sync_target.id}-#{e.class.name}"
      Webhookdb::Idempotency.every(1.hour).in_memory.under_key(idem_key) do
        self.sync_target.logger.warn("sync_target_http_error", self.sync_target.log_tags, e)
      end
    end

    def _flush_http_chunk(chunk_started, chunk)
      Webhookdb::Async.long_running_job_heartbeat!
      chunk_ts = chunk.last.fetch(self.replicator.timestamp_column.name)
      @mutex.synchronize do
        @inflight_timestamps << chunk_ts
        @inflight_timestamps.sort!
      end
      sint = self.sync_target.service_integration
      body = {
        rows: chunk,
        integration_id: sint.opaque_id,
        integration_service: sint.service_name,
        table: sint.table_name,
        sync_timestamp: self.now,
      }
      @threadpool.post do
        self.with_stat(chunk_started) do
          Webhookdb::Http.post(
            @cleanurl,
            body,
            timeout: sint.organization.sync_target_timeout,
            logger: self.sync_target.logger,
            basic_auth: @authparams,
          )
        end
        # On success, we want to commit the latest timestamp we sent to the client,
        # so it can be recorded. Then in the case of an error on later rows,
        # we won't re-sync rows we've already processed (with earlier updated timestamps).
        @mutex.synchronize do
          this_ts_idx = @inflight_timestamps.index { |t| t == chunk_ts }
          raise Webhookdb::InvariantViolation, "timestamp no longer found!?" if this_ts_idx.nil?
          # However, we only want to record the timestamp if this request is the earliest inflight request;
          # ie, if a later request finishes before an earlier one, we don't want to record the timestamp
          # of the later request as 'finished' since the earlier one didn't finish.
          # This does mean though that, if the earliest request errors, we'll throw away the work
          # done by the later request.
          # Note that each row can only appear in a sync once, even if it is modified after the sync starts;
          # thus, parallel httpsync should be fine for most clients to handle,
          # since race conditions *on the same row* cannot happen even with parallel httpsync.
          self.record(chunk_ts) if this_ts_idx.zero?
          @inflight_timestamps.delete_at(this_ts_idx)
        end
      end
    end
  end

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
  #
  class DatabaseRoutine < Routine
    def initialize(now, sync_target)
      super
      @connection_url = self.sync_target.connection_url
      @adapter = Webhookdb::DBAdapter.adapter(@connection_url)
      @adapter_connection = @adapter.connection(@connection_url)
    end

    def run
      schema_name = @sync_target.schema.present? ? @sync_target.schema : @sync_target.class.default_schema
      table_name = @sync_target.table.present? ? @sync_target.table : @sync_target.service_integration.table_name
      adapter = @adapter
      schema = Webhookdb::DBAdapter::Schema.new(name: schema_name.to_sym)
      table = Webhookdb::DBAdapter::Table.new(name: table_name.to_sym, schema:)

      schema_lines = []
      schema_lines << adapter.create_schema_sql(table.schema, if_not_exists: true)
      schema_lines << adapter.create_table_sql(
        table,
        [@replicator.primary_key_column, @replicator.remote_key_column],
        if_not_exists: true,
      )
      (@replicator.denormalized_columns + [@replicator.data_column]).each do |col|
        schema_lines << adapter.add_column_sql(table, col, if_not_exists: true)
      end
      adapter_conn = adapter.connection(@connection_url)
      schema_expr = schema_lines.join(";\n") + ";"
      if schema_expr != self.sync_target.last_applied_schema
        adapter_conn.execute(schema_expr)
        self.perform_db_op do
          self.sync_target.update(last_applied_schema: schema_expr)
        end
      end
      tempfile = Tempfile.new("whdbsyncout-#{self.sync_target.id}")
      begin
        self.dataset_to_sync do |ds|
          ds.db.copy_table(ds, options: "DELIMITER ',', HEADER true, FORMAT csv") do |row|
            tempfile.write(row)
          end
        end
        tempfile.rewind
        adapter.merge_from_csv(
          adapter_conn,
          tempfile,
          table,
          @replicator.primary_key_column,
          [@replicator.primary_key_column,
           @replicator.remote_key_column,] + @replicator.denormalized_columns + [@replicator.data_column],
        )
        self.record(self.now)
      ensure
        tempfile.unlink
      end
    end
  end
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
#  page_size              | integer                  | NOT NULL
#  text_search            | tsvector                 |
# Indexes:
#  sync_targets_pkey                         | PRIMARY KEY btree (id)
#  sync_targets_opaque_id_key                | UNIQUE btree (opaque_id)
#  sync_targets_last_synced_at_index         | btree (last_synced_at)
#  sync_targets_service_integration_id_index | btree (service_integration_id)
# Foreign key constraints:
#  sync_targets_created_by_id_fkey          | (created_by_id) REFERENCES customers(id) ON DELETE SET NULL
#  sync_targets_service_integration_id_fkey | (service_integration_id) REFERENCES service_integrations(id) ON DELETE CASCADE
# --------------------------------------------------------------------------------------------------------------------------
