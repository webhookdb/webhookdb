# frozen_string_literal: true

require "appydays/loggable"
require "concurrent-ruby"

require "webhookdb/backfiller"
require "webhookdb/db_adapter"
require "webhookdb/connection_cache"
require "webhookdb/replicator/column"
require "webhookdb/replicator/schema_modification"
require "webhookdb/replicator/webhook_request"
require "webhookdb/typed_struct"

require "webhookdb/jobs/send_webhook"
require "webhookdb/jobs/sync_target_run_sync"

class Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::DBAdapter::ColumnTypes

  # Return the descriptor for this service.
  # @abstract
  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    raise NotImplementedError, "#{self.class}: must return a descriptor that is used for registration purposes"
  end

  # @return [Webhookdb::ServiceIntegration]
  attr_reader :service_integration

  def initialize(service_integration)
    @service_integration = service_integration
  end

  # @return [Webhookdb::Replicator::Descriptor]
  def descriptor
    return @descriptor ||= self.class.descriptor
  end

  def resource_name_singular
    return @resource_name_singular ||= self.descriptor.resource_name_singular
  end

  def resource_name_plural
    return @resource_name_plural ||= self.descriptor.resource_name_plural
  end

  # Return true if the service should process webhooks in the actual endpoint,
  # rather than asynchronously through the job system.
  # This should ONLY be used where we have important order-of-operations
  # in webhook processing and/or need to return data to the webhook sender.
  #
  # NOTE: You MUST implement +synchronous_processing_response_body+ if this returns true.
  #
  # @return [Boolean]
  def process_webhooks_synchronously?
    return false
  end

  # Call with the value that was inserted by synchronous processing.
  # Takes the row values being upserted (result upsert_webhook),
  # and the arguments used to upsert it (arguments to upsert_webhook),
  # and should return the body string to respond back with.
  #
  # @param [Hash,Array] upserted
  # @param [Webhookdb::Replicator::WebhookRequest] request
  # @return [String]
  def synchronous_processing_response_body(upserted:, request:)
    return {message: "process synchronously"}.to_json if Webhookdb::Replicator.always_process_synchronously
    raise NotImplementedError, "must be implemented if process_webhooks_synchronously? is true"
  end

  # In some cases, services may send us sensitive headers we do not want to log.
  # This should be very rare but some services are designed really badly and send auth info in the webhook.
  # Remove or obfuscate the passed header hash.
  def preprocess_headers_for_logging(headers); end

  # Return a tuple of (schema, table) based on the organization's replication schema,
  # and the service integration's table name.
  #
  # @return [Array<Symbol>]
  def schema_and_table_symbols
    sch = self.service_integration.organization&.replication_schema&.to_sym || :public
    tbl = self.service_integration.table_name.to_sym
    return [sch, tbl]
  end

  # Return a Sequel identifier using +schema_and_table_symbols+,
  # or +schema+ or +table+ as overrides if given.
  #
  # @return [Sequel::SQL::QualifiedIdentifier]
  def qualified_table_sequel_identifier(schema: nil, table: nil)
    sch, tbl = self.schema_and_table_symbols
    return Sequel[schema || sch][table || tbl]
  end

  # Return a DBAdapter table based on the +schema_and_table_symbols+.
  # @return [Webhookdb::DBAdapter::Table]
  def dbadapter_table
    sch, tbl = self.schema_and_table_symbols
    schema = Webhookdb::DBAdapter::Schema.new(name: sch)
    table = Webhookdb::DBAdapter::Table.new(name: tbl, schema:)
    return table
  end

  # +Time.at(t)+, but nil if t is nil.
  # Use when we have 'nullable' integer timestamps.
  # @return [Time]
  protected def tsat(t)
    return nil if t.nil?
    return Time.at(t)
  end

  # Given a Rack request, return the webhook response object.
  # Usually this performs verification of the request based on the webhook secret
  # configured on the service integration.
  # Note that if +skip_webhook_verification+ is true on the service integration,
  # this method always returns 201.
  #
  # @param [Rack::Request] request
  # @return [Webhookdb::WebhookResponse]
  def webhook_response(request)
    return Webhookdb::WebhookResponse.ok(status: 201) if self.service_integration.skip_webhook_verification
    return self._webhook_response(request)
  end

  # Return a the response for the webhook.
  # We must do this immediately in the endpoint itself,
  # since verification may include info specific to the request content
  # (like, it can be whitespace sensitive).
  # @abstract
  # @param [Rack::Request] request
  # @return [Webhookdb::WebhookResponse]
  def _webhook_response(request)
    raise NotImplementedError
  end

  # If we support webhooks, these fields correspond to the webhook state machine.
  # Override them if some other fields are also needed for webhooks.
  def _webhook_state_change_fields = ["webhook_secret"]

  # If we support backfilling, these keys are used for them.
  # Override if other fields are used instead.
  # There cannot be overlap between these and the webhook state change fields.
  def _backfill_state_change_fields = ["backfill_key", "backfill_secret", "api_url"]

  # Set the new service integration field and
  # return the newly calculated state machine.
  #
  # Subclasses can override this method and then super,
  # to change the field or value.
  #
  # @param field [String] Like 'webhook_secret', 'backfill_key', etc.
  # @param value [String] The value of the field.
  # @param attr [String] Subclasses can pass in a custom field that does not correspond
  #   to a service integration column. When doing that, they must pass in attr,
  #   which is what will be set during the state change.
  # @return [Webhookdb::Replicator::StateMachineStep]
  def process_state_change(field, value, attr: nil)
    attr ||= field
    desc = self.descriptor
    value = value.strip if value.respond_to?(:strip)
    case field
      when *self._webhook_state_change_fields
        # If we don't support webhooks, then the backfill state machine may be using it.
        meth = desc.supports_webhooks? ? :calculate_webhook_state_machine : :calculate_backfill_state_machine
      when *self._backfill_state_change_fields
        # If we don't support backfilling, then the create state machine may be using them.
        meth = desc.supports_backfill? ? :calculate_backfill_state_machine : :calculate_webhook_state_machine
      when "dependency_choice"
        # Choose an upstream dependency for an integration.
        # See where this is used for more details.
        meth = self.preferred_create_state_machine_method
        value = self._find_dependency_candidate(value)
        attr = "depends_on"
      when "noop_create"
        # Use this to just recalculate the state machine,
        # not make any changes to the data.
        return self.calculate_preferred_create_state_machine
      else
        raise ArgumentError, "Field '#{field}' is not valid for a state change"
    end
    self.service_integration.db.transaction do
      self.service_integration.send(:"#{attr}=", value)
      self.service_integration.save_changes
      step = self.send(meth)
      if step.successful? && meth == :calculate_backfill_state_machine
        # If we are processing the backfill state machine, and we finish successfully,
        # we always want to start syncing.
        self._enqueue_backfill_jobs(incremental: true)
      end
      return step
    end
  end

  # If the integration supports webhooks, then we want to do that on create.
  # If it's backfill only, then we fall back to that instead.
  # Things like choosing dependencies are webhook-vs-backfill agnostic,
  # so which machine we choose isn't that important (but it does happen during creation).
  # @return [Symbol]
  def preferred_create_state_machine_method
    return self.descriptor.supports_webhooks? ? :calculate_webhook_state_machine : :calculate_backfill_state_machine
  end

  # See +preferred_create_state_machine_method+.
  # If we prefer backfilling, and it's successful, we also want to enqueue jobs;
  # that is, use +calculate_and_backfill_state_machine+, not just +calculate_backfill_state_machine+.
  # @return [Webhookdb::Replicator::StateMachineStep]
  def calculate_preferred_create_state_machine
    m = self.preferred_create_state_machine_method
    return self.calculate_and_backfill_state_machine(incremental: true)[0] if m == :calculate_backfill_state_machine
    return self.calculate_webhook_state_machine
  end

  def _enqueue_backfill_jobs(incremental:, criteria: nil, recursive: true, enqueue: true)
    m = recursive ? :create_recursive : :create
    j = Webhookdb::BackfillJob.send(
      m,
      service_integration:,
      incremental:,
      criteria: criteria || {},
      created_by: Webhookdb.request_user_and_admin[0],
    )
    j.enqueue if enqueue
    return j
  end

  # @param value [String]
  def _find_dependency_candidate(value)
    int_val = value.strip.blank? ? 1 : value.to_i
    idx = int_val - 1
    dep_candidates = self.service_integration.dependency_candidates
    raise Webhookdb::InvalidPrecondition, "no dependency candidates" if dep_candidates.empty?
    raise Webhookdb::InvalidInput, "'#{value}' is not a valid dependency" if
      idx.negative? || idx >= dep_candidates.length
    return dep_candidates[idx]
  end

  # Return the state machine that is used when setting up this integration.
  # Usually this entails providing the user the webhook url,
  # and providing or asking for a webhook secret. In some cases,
  # this can be a lot more complex though.
  #
  # @abstract
  # @return [Webhookdb::Replicator::StateMachineStep]
  def calculate_webhook_state_machine
    raise NotImplementedError
  end

  # Return the state machine that is used when adding backfill support to an integration.
  # Usually this sets one or both of the backfill key and secret.
  #
  # @return [Webhookdb::Replicator::StateMachineStep]
  def calculate_backfill_state_machine
    # This is a pure function that can be tested on its own--the endpoints just need to return a state machine step
    raise NotImplementedError
  end

  # Run calculate_backfill_state_machine.
  # Then create and enqueue a new BackfillJob if it's successful.
  # Returns a tuple of the StateMachineStep and BackfillJob.
  # If the BackfillJob is returned, the StateMachineStep was successful;
  # otherwise no job is created and the second item is nil.
  # @return [Array<Webhookdb::StateMachineStep, Webhookdb::BackfillJob>]
  def calculate_and_backfill_state_machine(incremental:, criteria: nil, recursive: true, enqueue: true)
    step = self.calculate_backfill_state_machine
    bfjob = nil
    bfjob = self._enqueue_backfill_jobs(incremental:, criteria:, recursive:, enqueue:) if step.successful?
    return step, bfjob
  end

  # When backfilling is not supported, this message is used.
  # It can be overridden for custom explanations,
  # or descriptor#documentation_url can be provided,
  # which will use a default message.
  # If no documentation is available, a fallback message is used.
  def backfill_not_supported_message
    du = self.documentation_url
    if du.blank?
      msg = %(Sorry, you cannot backfill this integration. You may be looking for one of the following:

  webhookdb integrations reset #{self.service_integration.table_name}
      )
      return msg
    end
    msg = %(Sorry, you cannot manually backfill this integration.
Please refer to the documentation at #{du}
for information on how to refresh data.)
    return msg
  end

  # Remove all the information used in the initial creation of the integration so that it can be re-entered
  def clear_webhook_information
    self._clear_webook_information
    # If we don't support both webhooks and backfilling, we are safe to clear ALL fields
    # and get back into an initial state.
    self._clear_backfill_information unless self.descriptor.supports_webhooks_and_backfill?
    self.service_integration.save_changes
  end

  def _clear_webook_information
    self.service_integration.set(webhook_secret: "")
  end

  # Remove all the information needed for backfilling from the integration so that it can be re-entered
  def clear_backfill_information
    self._clear_backfill_information
    # If we don't support both webhooks and backfilling, we are safe to clear ALL fields
    # and get back into an initial state.
    self._clear_webook_information unless self.descriptor.supports_webhooks_and_backfill?
    self.service_integration.save_changes
  end

  def _clear_backfill_information
    self.service_integration.set(api_url: "", backfill_key: "", backfill_secret: "")
  end

  # Find a dependent service integration with the given service name.
  # If none are found, return nil. If multiple are found, raise,
  # as this should only be used for automatically managed integrations.
  # @param service_name [String,Array<String>]
  # @return [Webhookdb::ServiceIntegration,nil]
  def find_dependent(service_name)
    names = service_name.respond_to?(:to_ary) ? service_name : [service_name]
    sints = self.service_integration.dependents.filter { |si| names.include?(si.service_name) }
    raise Webhookdb::InvalidPrecondition, "there are multiple #{names.join('/')} integrations in dependents" if
      sints.length > 1
    return sints.first
  end

  # @return [Webhookdb::ServiceIntegration]
  def find_dependent!(service_name)
    sint = self.find_dependent(service_name)
    raise Webhookdb::InvalidPrecondition, "there is no #{service_name} integration in dependents" if sint.nil?
    return sint
  end

  # Use this to determine whether we should add an enrichment column in
  # the create table modification to store the enrichment body.
  def _store_enrichment_body?
    return false
  end

  def create_table(if_not_exists: false)
    cmd = self.create_table_modification(if_not_exists:)
    self.admin_dataset(timeout: :fast) do |ds|
      cmd.execute(ds.db)
    end
  end

  # Return the schema modification used to create the table where it does nto exist.
  # @return [Webhookdb::Replicator::SchemaModification]
  def create_table_modification(if_not_exists: false)
    table = self.dbadapter_table
    columns = [self.primary_key_column, self.remote_key_column]
    columns.concat(self.storable_columns)
    # 'data' column should be last, since it's very large, we want to see other columns in psql/pgcli first
    columns << self.data_column
    adapter = Webhookdb::DBAdapter::PG.new
    result = Webhookdb::Replicator::SchemaModification.new
    create_table = adapter.create_table_sql(table, columns, if_not_exists:, partition: self.partitioning)
    result.transaction_statements << create_table
    result.transaction_statements.concat(self.create_table_partitions(adapter))
    self.indexes(table).each do |dbindex|
      result.transaction_statements << adapter.create_index_sql(dbindex, concurrently: false)
    end
    result.application_database_statements << self.service_integration.ensure_sequence_sql if self.requires_sequence?
    return result
  end

  # True if the replicator uses partitioning.
  def partition? = false
  # Non-nil only if +partition?+ is true.
  # @return [Webhookdb::DBAdapter::Partitioning,nil]
  def partitioning = nil

  # Return the partitions belonging to the table.
  # Return an empty array if this replicator is not partitioned.
  # @return [Array<Webhookdb::DBAdapter::Partition>]
  def existing_partitions(_db)
    raise NotImplementedError if self.partition?
    return []
  end

  def create_table_partitions(adapter)
    return [] unless self.partition?
    # We only need create_table partitions when we create the table.
    # Range partitions would be created on demand, when inserting rows and the partition doesn't exist.
    return [] unless self.partitioning.by == Webhookdb::DBAdapter::Partitioning::HASH

    max_partition = self.service_integration.partition_value
    raise Webhookdb::InvalidPrecondition, "partition value must be positive" unless max_partition.positive?
    stmts = (0...max_partition).map do |i|
      adapter.create_hash_partition_sql(self.dbadapter_table, max_partition, i)
    end
    return stmts
  end

  # We need to give indexes a persistent name, unique across the schema,
  # since multiple indexes within a schema cannot share a name.
  #
  # Note that in certain RDBMS (Postgres) index names cannot exceed a certian length;
  # Postgres will silently truncate them. This can result in an index not being created
  # if it shares the same name as another index, and we use 'CREATE INDEX IF NOT EXISTS.'
  #
  # To avoid this, if the generated name exceeds a certain size, an md5 hash of the column names is used.
  #
  # @param columns [Array<Webhookdb::DBAdapter::Column, Webhookdb::Replicator::Column>] Must respond to :name.
  # @param identifier [String,nil] Use this instead of a combination of column names.
  #   Only use this where multiple indexes are needed for the same columns, but something like the 'where'
  #   condition is different.
  # @return [String]
  protected def index_name(columns, identifier: nil)
    raise Webhookdb::InvalidPrecondition, "sint needs an opaque id" if self.service_integration.opaque_id.blank?
    colnames = columns.map(&:name).join("_")
    opaque_id = self.service_integration.opaque_id
    # Handle old IDs without the leading 'svi_'.
    opaque_id = "idx#{opaque_id}" if /\d/.match?(opaque_id[0])

    if identifier
      name = "#{opaque_id}_#{identifier}_idx"
    else
      name = "#{opaque_id}_#{colnames}_idx"
      if name.size > MAX_INDEX_NAME_LENGTH
        # We don't have the 32 extra chars for a full md5 hash.
        # We can't convert to Base64 or whatever, since we don't want to depend on case sensitivity.
        # So just lop off a few characters (normally 2) from the end of the md5.
        # The collision space is so small (some combination of column names would need to have the
        # same md5, which is unfathomable), we're not really worried about it.
        colnames_md5 = Digest::MD5.hexdigest(colnames)
        available_chars = MAX_INDEX_NAME_LENGTH - "#{opaque_id}__idx".size
        name = "#{opaque_id}_#{colnames_md5[...available_chars]}_idx"
      end
    end
    raise Webhookdb::InvariantViolation, "index names cannot exceed 63 chars, got #{name.size} in '#{name}'" if
      name.size > 63
    return name
  end

  MAX_INDEX_NAME_LENGTH = 63

  # @return [Webhookdb::DBAdapter::Column]
  def primary_key_column
    return Webhookdb::DBAdapter::Column.new(name: :pk, type: BIGINT, pk: true)
  end

  # @return [Webhookdb::DBAdapter::Column]
  def remote_key_column
    c = self._remote_key_column
    if c.index?
      msg = "_remote_key_column index:true should not be set, since it automatically gets a unique index"
      Kernel.warn msg
    end
    return c.to_dbadapter(unique: true, nullable: false, index: false)
  end

  # @return [Webhookdb::DBAdapter::Column]
  def data_column
    return Webhookdb::DBAdapter::Column.new(name: :data, type: OBJECT, nullable: false)
  end

  # Column used to store enrichments. Return nil if the service does not use enrichments.
  # @return [Webhookdb::DBAdapter::Column,nil]
  def enrichment_column
    return nil unless self._store_enrichment_body?
    return Webhookdb::DBAdapter::Column.new(name: :enrichment, type: OBJECT, nullable: true)
  end

  # @return [Array<Webhookdb::DBAdapter::Column>]
  def denormalized_columns
    return self._denormalized_columns.map(&:to_dbadapter)
  end

  # Names of columns for multi-column indexes.
  # Each one must be in +denormalized_columns+.
  # @return [Array<Webhook::Replicator::IndexSpec>]
  def _extra_index_specs
    return []
  end

  # Denormalized columns, plus the enrichment column if supported.
  # Does not include the data or external id columns, though perhaps it should.
  # @return [Array<Webhookdb::DBAdapter::Column>]
  def storable_columns
    cols = self.denormalized_columns
    if (enr = self.enrichment_column)
      cols << enr
    end
    return cols
  end

  # Column to use as the 'timestamp' for the row.
  # This is usually some created or updated at timestamp.
  # @return [Webhookdb::DBAdapter::Column]
  def timestamp_column
    got = self._denormalized_columns.find { |c| c.name == self._timestamp_column_name }
    raise NotImplementedError, "#{self.descriptor.name} has no timestamp column #{self._timestamp_column_name}" if
      got.nil?
    return got.to_dbadapter
  end

  # The name of the timestamp column in the schema. This column is used primarily for conditional upserts
  # (ie to know if a row has changed), but also as a general way of auditing changes.
  # @abstract
  # @return [Symbol]
  def _timestamp_column_name
    raise NotImplementedError
  end

  # Each integration needs a single remote key, like the Shopify order id for shopify orders,
  # or sid for Twilio resources. This column must be unique for the table, like a primary key.
  #
  # NOTE: Do not set index:true. The remote key column always must be unique,
  # so it gets a unique index automatically.
  #
  # @abstract
  # @return [Webhookdb::Replicator::Column]
  def _remote_key_column
    raise NotImplementedError
  end

  # When an integration needs denormalized columns, specify them here.
  # Indexes are created for each column.
  # Modifiers can be used if columns should have a default or whatever.
  # See +Webhookdb::Replicator::Column+ for more details about column fields.
  #
  # @return [Array<Webhookdb::Replicator::Column]
  def _denormalized_columns
    return []
  end

  # @return [Array<Webhookdb::DBAdapter::Index>]
  def indexes(table)
    dba_columns = [self.primary_key_column, self.remote_key_column]
    dba_columns.concat(self.storable_columns)
    dba_cols_by_name = dba_columns.index_by(&:name)

    result = []
    dba_columns.select(&:index?).each do |c|
      targets = [c]
      idx_name = self.index_name(targets)
      result << Webhookdb::DBAdapter::Index.new(name: idx_name.to_sym, table:, targets:, where: c.index_where)
    end
    self._extra_index_specs.each do |spec|
      targets = spec.columns.map { |n| dba_cols_by_name.fetch(n) }
      idx_name = self.index_name(targets, identifier: spec.identifier)
      result << Webhookdb::DBAdapter::Index.new(name: idx_name.to_sym, table:, targets:, where: spec.where)
    end
    index_names = result.map(&:name)
    if (dupes = index_names.find_all.with_index { |n, idx| idx != index_names.rindex(n) }).any?
      msg = "Duplicate index names detected. Use the 'name' attribute to differentiate: " +
        dupes.map(&:to_s).join(", ")
      raise Webhookdb::Replicator::BrokenSpecification, msg
    end

    return result
  end

  # We support adding columns to existing integrations without having to bump the version;
  # changing types, or removing/renaming columns, is not supported and should bump the version
  # or must be handled out-of-band (like deleting the integration then backfilling).
  # To figure out what columns we need to add, we can check what are currently defined,
  # check what exists, and add denormalized columns and indexes for those that are missing.
  def ensure_all_columns
    modification = self.ensure_all_columns_modification
    return if modification.noop?
    self.admin_dataset(timeout: :slow_schema) do |ds|
      modification.execute(ds.db)
      # We need to clear cached columns on the data since we know we're adding more.
      # It's probably not a huge deal but may as well keep it in sync.
      ds.send(:clear_columns_cache)
    end
    self.readonly_dataset { |ds| ds.send(:clear_columns_cache) }
  end

  # @return [Webhookdb::Replicator::SchemaModification]
  def ensure_all_columns_modification
    existing_cols, existing_indexes, existing_partitions = nil
    adapter = Webhookdb::DBAdapter::PG.new
    sint = self.service_integration
    table = self.dbadapter_table
    self.admin_dataset do |ds|
      return self.create_table_modification unless ds.db.table_exists?(self.qualified_table_sequel_identifier)
      existing_cols = ds.columns.to_set
      adapter.delete_invalid_indexes(ds.db, table)
      existing_indexes = adapter.select_existing_indexes(ds.db, table).map { |n| Sequel[table.name][n] }
      existing_partitions = self.existing_partitions(ds.db)
    end
    result = Webhookdb::Replicator::SchemaModification.new

    missing_columns = self._denormalized_columns.delete_if { |c| existing_cols.include?(c.name) }
    # Add missing columns
    missing_columns.each do |whcol|
      # Don't bother bulking the ADDs into a single ALTER TABLE, it won't really matter.
      result.transaction_statements << adapter.add_column_sql(table, whcol.to_dbadapter)
    end
    # Easier to handle this explicitly than use storage_columns, but it a duplicated concept so be careful.
    if (enrich_col = self.enrichment_column) && !existing_cols.include?(enrich_col.name)
      result.transaction_statements << adapter.add_column_sql(table, enrich_col)
    end

    # Backfill values for new columns.
    if missing_columns.any?
      # We need to backfill values into the new column, but we don't want to lock the entire table
      # as we update each row. So we need to update in chunks of rows.
      # Chunk size should be large for speed (and sending over fewer queries), but small enough
      # to induce a viable delay if another query is updating the same row.
      # Note that the delay will only be for writes to those rows; reads will not block,
      # so something a bit longer should be ok.
      #
      # Note that at the point these UPDATEs are running, we have the new column AND the new code inserting
      # into that new column. We could in theory skip all the PKs that were added after this modification
      # started to run. However considering the number of rows in this window will always be relatively low
      # (though not absolutely low), and the SQL backfill operation should yield the same result
      # as the Ruby operation, this doesn't seem too important.
      result.nontransaction_statements.concat(missing_columns.filter_map(&:backfill_statement))
      update_expr = missing_columns.to_h { |c| [c.name, c.backfill_expr || c.to_sql_expr] }
      self.admin_dataset do |ds|
        # Calculate the maximum pk only if we need it.
        # We cannot just do `ds.max(:pk) || 0`, since it is very slow for large tables;
        # in fact, it does an index-only scan of potentially billions of rows!
        # Instead, take advantage of the fact that this is a sequence, not a normal row,
        # and peek at the next value for the pk sequence.
        max_pk = adapter.get_serial_sequence_last_value(ds.db, sint.table_name, "pk")
        chunks = Webhookdb::Replicator::Base.chunked_row_update_bounds(max_pk)
        chunks[...-1].each do |(lower, upper)|
          update_query = ds.where { pk > lower }.where { pk <= upper }.update_sql(update_expr)
          result.nontransaction_statements << update_query
        end
        final_update_query = ds.where { pk > chunks[-1][0] }.update_sql(update_expr)
        result.nontransaction_statements << final_update_query
      end
    end

    # Add missing indexes. This should happen AFTER the UPDATE calls so the UPDATEs don't have to update indexes.
    self.indexes(table).map do |index|
      next if Webhookdb::Replicator.refers_to_any_same_index?(Sequel[table.name][index.name], existing_indexes)
      result.nontransaction_statements.concat(
        adapter.create_index_sqls(index, concurrently: true, partitions: existing_partitions),
      )
    end

    result.application_database_statements << sint.ensure_sequence_sql if self.requires_sequence?
    return result
  end

  def align_index_names
    regex = /^svi_[0-9a-z]+/
    opaqueid = self.service_integration.opaque_id
    org = self.service_integration.organization
    org.admin_connection do |db|
      records = db[Sequel[:pg_indexes]].
        where(schemaname: org.replication_schema, tablename: self.service_integration.table_name).
        select_map([:schemaname, :indexname])
      records.each do |(sch, idx)|
        next if idx.start_with?(opaqueid) # Does not need to be aligned
        match = idx.match(regex)
        next unless match # Ignore non-opaque id indexes
        base_name = idx[match.to_s.length..]
        new_name = "#{opaqueid}#{base_name}"
        db << "ALTER INDEX #{sch}.#{idx} RENAME TO #{new_name}"
      end
    end
  end

  # Return an array of tuples used for splitting UPDATE queries so locks are not held on the entire table
  # when backfilling values when adding new columns. See +ensure_all_columns_modification+.
  #
  # The returned chunks are like: [[0, 100], [100, 200], [200]],
  # and meant to be used like `0 < pk <= 100`, `100 < pk <= 200`, `p, > 200`.
  #
  # Note that final value in the array is a single item, used like `pk > chunks[-1][0]`.
  def self.chunked_row_update_bounds(max_pk, chunk_size: 1_000_000)
    result = []
    chunk_lower_pk = 0
    chunk_upper_pk = chunk_size
    while chunk_upper_pk <= max_pk
      # Get chunks like 0 < pk <= 100, 100 < pk <= 200, etc
      # Each loop we increment one row chunk size, until we find the chunk containing our max PK.
      # Ie if row chunk size is 100, and max_pk is 450, the final chunk here is 400-500.
      result << [chunk_lower_pk, chunk_upper_pk]
      chunk_lower_pk += chunk_size
      chunk_upper_pk += chunk_size
    end
    # Finally, one final chunk for all rows greater than our biggest chunk.
    # For example, with a row chunk size of 100, and max_pk of 450, we got a final chunk of 400-500.
    # But we could have gotten 100 writes (with a new max pk of 550), so this 'pk > 500' catches those.
    result << [chunk_lower_pk]
  end

  # Some integrations require sequences, like when upserting rows with numerical unique ids
  # (if they were random values like UUIDs we could generate them and not use a sequence).
  # In those cases, the integrations can mark themselves as requiring a sequence.
  #
  # The sequence will be created in the *application database*,
  # but it used primarily when inserting rows into the *organization/replication database*.
  # This is necessary because things like sequences are not possible to migrate
  # when moving replication databases.
  def requires_sequence?
    return false
  end

  # A given HTTP request may not be handled by the service integration it was sent to,
  # for example where the service integration is part of some 'root' hierarchy.
  # This method is called in the webhook endpoint, and should return the replicator
  # used to handle the webhook request. The request is validated by the returned instance,
  # and it is enqueued for processing.
  #
  # By default, the service called by the webhook is the one we want to use,
  # so return self.
  #
  # @param request [Rack::Request]
  # @return [Webhookdb::Replicator::Base]
  def dispatch_request_to(request)
    return self
  end

  # Upsert webhook using only a body.
  # This is not valid for the rare integration which does not rely on request info,
  # like when we have to take different action based on a request method.
  #
  # @param body [Hash]
  # @return [Array,Hash] Inserted rows, or array of inserted rows if many.
  def upsert_webhook_body(body, **kw)
    return self.upsert_webhook(Webhookdb::Replicator::WebhookRequest.new(body:), **kw)
  end

  # Upsert a webhook request into the database. Note this is a WebhookRequest,
  # NOT a Rack::Request.
  #
  # @param [Webhookdb::Replicator::WebhookRequest] request
  # @return [Array,Hash] Inserted rows, or array of inserted rows if many.
  def upsert_webhook(request, **kw)
    return self._upsert_webhook(request, **kw)
  rescue Amigo::Retry::Error
    # Do not log this since it's expected/handled by Amigo
    raise
  rescue StandardError => e
    self.logger.error("upsert_webhook_error", {request: request.as_json}, e)
    raise
  end

  # Hook to be overridden, while still retaining
  # top-level upsert_webhook functionality like error handling.
  #
  # @param request [Webhookdb::Replicator::WebhookRequest]
  # @param upsert [Boolean] If false, just return what would be upserted.
  # @return [Array,Hash] Inserted rows, or array of inserted rows if many.
  def _upsert_webhook(request, upsert: true)
    resource_or_list, event = self._resource_and_event(request)
    return nil if resource_or_list.nil?
    if resource_or_list.is_a?(Array)
      unless event.nil?
        msg = "resource_and_event cannot return an array of resources with a non-nil event"
        raise Webhookdb::InvalidPostcondition, msg
      end
      return resource_or_list.map do |resource|
        self._upsert_webhook_single_resource(request, resource:, event:, upsert:)
      end
    end
    return self._upsert_webhook_single_resource(request, resource: resource_or_list, event:, upsert:)
  end

  def _upsert_webhook_single_resource(request, resource:, event:, upsert:)
    enrichment = self._fetch_enrichment(resource, event, request)
    prepared = self._prepare_for_insert(resource, event, request, enrichment)
    raise Webhookdb::InvalidPostcondition if prepared.key?(:data)
    inserting = {}
    data_col_val = self._resource_to_data(resource, event, request, enrichment)
    inserting[:data] = self._to_json(data_col_val)
    inserting[:enrichment] = self._to_json(enrichment) if self._store_enrichment_body?
    inserting.merge!(prepared)
    return inserting unless upsert
    updating = self._upsert_update_expr(inserting, enrichment:)
    update_where = self._update_where_expr
    upserted_rows = self.admin_dataset(timeout: :fast) do |ds|
      ds.insert_conflict(
        target: self._upsert_conflict_target,
        update: updating,
        update_where:,
      ).insert(inserting)
    end
    row_changed = upserted_rows.present?
    self._notify_dependents(inserting, row_changed)
    self._publish_rowupsert(inserting) if row_changed
    return inserting
  end

  # The target for ON CONFLICT. Usually the remote key column name,
  # except if the remote id is a compound unique index, like for partitioned tables.
  # Can be a symbol, array of symbols representing the column names, a +Sequel.lit+, etc.
  # See +Sequel::Dataset.insert_conflict+ :target option for details.
  def _upsert_conflict_target = self._remote_key_column.name

  # The NULL ASCII character (\u0000), when present in a string ("\u0000"),
  # and then encoded into JSON ("\\u0000") is invalid in PG JSONB- its strings cannot contain NULLs
  # (note that JSONB does not store the encoded string verbatim, it parses it into PG types, and a PG string
  # cannot contain NULL since C strings are NULL-terminated).
  #
  # So we remove the "\\u0000" character from encoded JSON- for example, in the hash {x: "\u0000"},
  # if we #to_json, we end up with '{"x":"\\u0000"}'. The removal of encoded NULL gives us '{"x":""}'.
  #
  # HOWEVER, if the encoded null is itself escaped, we MUST NOT remove it.
  # For example, in the hash {x: "\u0000".to_json}.to_json (ie, a JSON string which contains another JSON string),
  # we end up with '{"x":"\\\\u0000"}`, That is, a string containing the *escaped* null character.
  # This is valid for PG, because it's not a NULL- it's an escaped "\", followed by "u0000".
  # If we were to remove the string "\\u0000", we'd end up with '{"x":"\\"}'. This creates an invalid document.
  #
  # So we remove only "\\u0000" by not replacing "\\\\u0000"- replace all occurences of
  # "<any one character except backslash>\\u0000" with "<character before backslash>".
  def _to_json(v)
    return v.to_json.gsub(/(\\\\u0000|\\u0000)/, {"\\\\u0000" => "\\\\u0000", "\\u0000" => ""})
  end

  # @param changed [Boolean]
  def _notify_dependents(inserting, changed)
    self.service_integration.dependents.each do |d|
      d.replicator.on_dependency_webhook_upsert(self, inserting, changed:)
    end
  end

  def _any_subscriptions_to_notify?
    return !self.service_integration.all_webhook_subscriptions_dataset.to_notify.empty?
  end

  def _publish_rowupsert(row, check_for_subscriptions: true)
    return unless check_for_subscriptions && self._any_subscriptions_to_notify?
    payload = [
      self.service_integration.id,
      {
        row:,
        external_id_column: self._remote_key_column.name,
        external_id: row[self._remote_key_column.name],
      },
    ]
    # We AVOID pubsub here because we do NOT want to go through the router
    # and audit logger for this.
    event = Amigo::Event.create("webhookdb.serviceintegration.rowupsert", payload.as_json)
    Webhookdb::Jobs::SendWebhook.perform_async(event.as_json)
  end

  # Return true if the integration requires making an API call to upsert.
  # This puts the sync into a lower-priority queue
  # so it is less likely to block other processing.
  # This is usually true if enrichments are involved.
  # @return [Boolean]
  def upsert_has_deps?
    return false
  end

  # Given the resource that is going to be inserted and an optional event,
  # make an API call to enrich it with further data if needed.
  # The result of this is passed to _prepare_for_insert.
  #
  # @param [Hash,nil] resource
  # @param [Hash,nil] event
  # @param [Webhookdb::Replicator::WebhookRequest] request
  # @return [*]
  def _fetch_enrichment(resource, event, request)
    return nil
  end

  # The argument for insert_conflict update_where clause.
  # Used to conditionally update, like updating only if a row is newer than what's stored.
  # We must always have an 'update where' because we never want to overwrite with the same data
  # as exists.
  #
  # @example With a meaningful timestmap
  #   self.qualified_table_sequel_identifier[:updated_at] < Sequel[:excluded][:updated_at]
  #
  # If an integration does not have any way to detect if a resource changed,
  # it can compare data columns.
  #
  # @example Without a meaingful timestamp
  #   self.qualified_table_sequel_identifier[:data] !~ Sequel[:excluded][:data]
  #
  # @abstract
  # @return [Sequel::SQL::Expression]
  def _update_where_expr
    raise NotImplementedError
  end

  # Given a webhook/backfill item payload,
  # return the resource hash, and an optional event hash.
  # If 'body' is the resource itself,
  # this method returns [body, nil].
  # If 'body' is an event,
  # this method returns [body.resource-key, body].
  # Columns can check for whether there is an event and/or body
  # when converting.
  #
  # If this returns nil, the upsert is skipped.
  #
  # For example, a Stripe customer backfill upsert would be `{id: 'cus_123'}`
  # when we backfill, but `{type: 'event', data: {id: 'cus_123'}}` when handling an event.
  #
  # @abstract
  # @param [Webhookdb::Replicator::WebhookRequest] request
  # @return [Array<Hash,Array>,nil]
  def _resource_and_event(request)
    raise NotImplementedError
  end

  # Return the hash that should be inserted into the database,
  # based on the denormalized columns and data given.
  # @param [Hash,nil] resource
  # @param [Hash,nil] event
  # @param [Webhookdb::Replicator::WebhookRequest] request
  # @param [Hash,nil] enrichment
  # @return [Hash]
  def _prepare_for_insert(resource, event, request, enrichment)
    h = [self._remote_key_column].concat(self._denormalized_columns).each_with_object({}) do |col, memo|
      value = col.to_ruby_value(resource:, event:, enrichment:, service_integration:)
      skip = value.nil? && col.skip_nil?
      memo[col.name] = value unless skip
    end
    return h
  end

  # Given the resource, return the value for the :data column.
  # Only needed in rare situations where fields should be stored
  # on the row, but not in :data.
  # To skip :data column updates, return nil.
  # @param [Hash,nil] resource
  # @param [Hash,nil] event
  # @param [Webhookdb::Replicator::WebhookRequest] request
  # @param [Hash,nil] enrichment
  # @return [Hash]
  def _resource_to_data(resource, event, request, enrichment)
    return resource
  end

  # Given the hash that is passed to the Sequel insert
  # (so contains all columns, including those from _prepare_for_insert),
  # return the hash used for the insert_conflict(update:) keyword args.
  #
  # Rather than sending over the literal values in the inserting statement
  # (which is pretty verbose, like the large 'data' column),
  # make a smaller statement by using 'EXCLUDED'.
  #
  # This can be overriden when the service requires different values
  # for inserting vs. updating, such as when a column's update value
  # must use the EXCLUDED table in the upsert expression.
  #
  # Most commonly, the use case for this is when you want to provide a row a value,
  # but ONLY on insert, OR on update by ONLY if the column is nil.
  # In that case, pass the result of this base method to
  # +_coalesce_excluded_on_update+ (see also for more details).
  #
  # You can also use this method to merge :data columns together. For example:
  # `super_result[:data] = Sequel.lit("#{self.service_integration.table_name}.data || excluded.data")`
  #
  # By default, this will use the same values for UPDATE as are used for INSERT,
  # like `email = EXCLUDED.email` (the 'EXCLUDED' row being the one that failed to insert).
  def _upsert_update_expr(inserting, enrichment: nil)
    result = inserting.each_with_object({}) { |(c, _), h| h[c] = Sequel[:excluded][c] }
    return result
  end

  # Have a column set itself only on insert or if nil.
  #
  # Given the payload to DO UPDATE, mutate it so that
  # the column names included in 'column_names' use what is already in the table,
  # and fall back to what's being inserted.
  # This new payload should be passed to the `update` kwarg of `insert_conflict`:
  #
  # ds.insert_conflict(update: self._coalesce_excluded_on_update(payload, :created_at)).insert(payload)
  #
  # @param update [Hash]
  # @param column_names [Array<Symbol>]
  def _coalesce_excluded_on_update(update, column_names)
    # Now replace just the specific columns we're overriding.
    column_names.each do |c|
      update[c] = Sequel.function(:coalesce, self.qualified_table_sequel_identifier[c], Sequel[:excluded][c])
    end
  end

  # Yield to a dataset using the admin connection.
  # @return [Sequel::Dataset]
  def admin_dataset(**kw, &)
    self.with_dataset(self.service_integration.organization.admin_connection_url_raw, **kw, &)
  end

  # Yield to a dataset using the readonly connection.
  # @return [Sequel::Dataset]
  def readonly_dataset(**kw, &)
    self.with_dataset(self.service_integration.organization.readonly_connection_url_raw, **kw, &)
  end

  protected def with_dataset(url, **kw, &block)
    raise LocalJumpError if block.nil?
    Webhookdb::ConnectionCache.borrow(url, **kw) do |conn|
      yield(conn[self.qualified_table_sequel_identifier])
    end
  end

  # Run the given block with a (try) advisory lock taken on a combination of:
  #
  # - The table OID for this replicator
  # - The given key
  #
  # Note this establishes a new DB connection for the advisory lock;
  # we have had issues with advisory locks on reused connections,
  # and this is safer than having a lock that is never released.
  def with_advisory_lock(key, &)
    url = self.service_integration.organization.admin_connection_url_raw
    got = nil

    # We use the (int, int) version of advisory lock, with the table id as the 'namespace'.
    # However, the second key is often a row PK, which can be a bigint on a very large table.
    # In these cases, we can relatively safely turn that into an integer.
    key2 = key
    # If the key is greater than 4B (max unsigned integer), put it between 0 and 4B.
    key2 %= Sequel::AdvisoryLock::MAX_UINT if
      key2 > Sequel::AdvisoryLock::MAX_UINT
    key2 = self._uint_to_intkey(key2) if
      key2 > Sequel::AdvisoryLock::MAX_INT
    raise ArgumentError, "key #{key} cannot be less than MIN_INT, use something else or change this code" if
      key2 < Sequel::AdvisoryLock::MIN_INT

    Webhookdb::Dbutil.borrow_conn(url) do |conn|
      table_oid = self._select_table_oid(conn)
      # oids are always a 4 byte uint, so if it's between 2B and 4B, move it to between -2B and 0.
      table_oid = self._uint_to_intkey(table_oid) if
        table_oid > Sequel::AdvisoryLock::MAX_INT
      self.logger.debug("taking_replicator_advisory_lock", table_oid:, key_id: key2)
      Sequel::AdvisoryLock.new(conn, table_oid, key2).with_lock? do
        got = yield
      end
    end
    return got
  end

  def _select_table_oid(conn)
    table_oid = conn.select(
      Sequel.function(:to_regclass, self.schema_and_table_symbols.join(".")).cast(:oid).as(:table_id),
    ).first[:table_id]
    return table_oid
  end

  # If the key is greater than 2B (so between max signed and unsigned integers),
  # we can bias it into a 'signed' integer. Use the ID space between -2B and 0 for this purpose,
  # since it is otherwise likely unused.
  def _uint_to_intkey(key2)
    (key2 - Sequel::AdvisoryLock::MAX_INT) * -1
  end

  # Some replicators support 'instant sync', because they are upserted en-masse
  # rather than row-by-row. That is, usually we run sync targets on a cron,
  # because otherwise we'd need to run the sync target for every row.
  # But if inserting is always done through backfilling,
  # we know we have a useful set of results to sync, so don't need to wait for cron.
  def enqueue_sync_targets
    self.service_integration.sync_targets.each do |stgt|
      Webhookdb::Jobs::SyncTargetRunSync.perform_async(stgt.id)
    end
  end

  class CredentialVerificationResult < Webhookdb::TypedStruct
    attr_reader :verified, :http_error_status

    def verified? = self.verified
  end

  # Try to verify backfill credentials, by fetching the first page of items.
  # Only relevant for integrations supporting backfilling.
  #
  # If an error is received, return the result with +http_error_status+ set.
  # Callers can use this error status to figure out the message to display to the user.
  #
  # @return [Webhookdb::CredentialVerificationResult]
  def verify_backfill_credentials
    backfiller = self._backfillers.first
    if backfiller.nil?
      # If for some reason we do not have a backfiller,
      # we can't verify credentials. This should never happen in practice,
      # because we wouldn't call this method if the integration doesn't support it.
      raise "No backfiller available for #{self.service_integration.inspect}"
    end
    begin
      # begin backfill attempt but do not return backfill result
      backfiller.fetch_backfill_page(nil, last_backfilled: nil)
    rescue Webhookdb::Http::Error => e
      return CredentialVerificationResult.new(verified: false, http_error_status: e.status)
    rescue TypeError, NoMethodError => e
      # if we don't incur an HTTP error, but do incur an Error due to differences in the shapes of anticipated
      # response data in the `fetch_backfill_page` function, we can assume that the credentials are okay
      self.logger.info "verify_backfill_credentials_expected_failure", e
      return CredentialVerificationResult.new(verified: true)
    end
    return CredentialVerificationResult.new(verified: true)
  end

  def documentation_url = nil

  # In order to backfill, we need to:
  # - Iterate through pages of records from the external service
  # - Upsert each record
  # The caveats/complexities are:
  # - The backfill method should take care of retrying fetches for failed pages.
  # - That means it needs to keep track of some pagination token.
  # @param job [Webhookdb::BackfillJob]
  def backfill(job)
    raise Webhookdb::InvalidPrecondition, "job is for different service integration" unless
      job.service_integration === self.service_integration

    raise Webhookdb::InvariantViolation, "manual backfill not supported" unless self.descriptor.supports_backfill?

    sint = self.service_integration
    raise Webhookdb::Replicator::CredentialsMissing if
      sint.backfill_key.blank? && sint.backfill_secret.blank? && sint.depends_on.blank?
    last_backfilled = job.incremental? ? sint.last_backfilled_at : nil
    new_last_backfilled = Time.now
    job.update(started_at: Time.now)

    backfillers = self._backfillers(**job.criteria.symbolize_keys)
    begin
      if self._parallel_backfill && self._parallel_backfill > 1
        _do_parallel_backfill(backfillers, last_backfilled)
      else
        _do_serial_backfill(backfillers, last_backfilled)
      end
    rescue StandardError => e
      if self.on_backfill_error(e) == true
        job.update(finished_at: Time.now)
        return
      end
      raise e
    end

    sint.update(last_backfilled_at: new_last_backfilled) if job.incremental?
    job.update(finished_at: Time.now)
    job.enqueue_children
  end

  protected def _do_parallel_backfill(backfillers, last_backfilled)
    # Create a dedicated threadpool for these backfillers,
    # with max parallelism determined by the replicator.
    pool = Concurrent::FixedThreadPool.new(self._parallel_backfill)
    # Record any errors that occur, since they won't raise otherwise.
    # Initialize a sized array to avoid any potential race conditions (though GIL should make it not an issue?).
    errors = Array.new(backfillers.size)
    backfillers.each_with_index do |bf, idx|
      pool.post do
        bf.backfill(last_backfilled)
      rescue StandardError => e
        errors[idx] = e
      end
    end
    # We've enqueued all backfillers; do not accept anymore work.
    pool.shutdown
    loop do
      # We want to stop early if we find an error, so check for errors every 10 seconds.
      completed = pool.wait_for_termination(10)
      first_error = errors.find { |e| !e.nil? }
      if first_error.nil?
        # No error, and wait_for_termination returned true, so all work is done.
        break if completed
        # No error, but work is still going on, so loop again.
        next
      end
      # We have an error; don't run any more backfillers.
      pool.kill
      # Wait for all ongoing backfills before raising.
      pool.wait_for_termination
      raise first_error
    end
  end

  protected def _do_serial_backfill(backfillers, last_backfilled)
    backfillers.each do |backfiller|
      backfiller.backfill(last_backfilled)
    end
  end

  # Called when the #backfill method errors.
  # This can do something like dispatch a developer alert.
  # The handler must raise in order to stop the job from processing-
  # if nothing is raised, the original exception will be raised instead.
  # By default, this method noops, so the original exception is raised.
  # @param e [Exception]
  def on_backfill_error(e) = nil

  # If this replicator supports backfilling in parallel (running multiple backfillers at a time),
  # return the degree of paralellism (or nil if not running in parallel).
  # We leave parallelism up to the replicator, not CPU count, since most work
  # involves waiting on APIs to return.
  #
  # NOTE: These threads are in addition to any worker threads, so it's important
  # to pay attention to memory use.
  def _parallel_backfill
    return nil
  end

  # Return backfillers for the replicator.
  # We must use an array for 'data-based' backfillers,
  # like when we need to paginate for each row in another table.
  #
  # By default, return a ServiceBackfiller,
  # which will call _fetch_backfill_page on the receiver.
  #
  # @return [Array<Webhookdb::Backfiller>]
  def _backfillers
    return [ServiceBackfiller.new(self)]
  end

  # Basic backfiller that calls +_fetch_backfill_page+ on the given replicator.
  # Any timeouts or 5xx errors are automatically re-enqueued for a retry.
  # This behavior can be customized somewhat setting :backfiller_server_error_retries (default to 2)
  # and :backfiller_server_error_backoff on the replicator (default to 63 seconds),
  # though customization beyond that should use a custom backfiller.
  class ServiceBackfiller < Webhookdb::Backfiller
    # @!attribute svc
    #   @return [Webhookdb::Replicator::Base]
    attr_reader :svc

    attr_accessor :server_error_retries, :server_error_backoff

    def initialize(svc)
      @svc = svc
      @server_error_retries = _getifrespondto(:backfiller_server_error_retries, 2)
      @server_error_backoff = _getifrespondto(:backfiller_server_error_backoff, 63.seconds)
      raise "#{svc} must implement :_fetch_backfill_page" unless svc.respond_to?(:_fetch_backfill_page)
      super()
    end

    private def _getifrespondto(sym, default)
      return default unless @svc.respond_to?(sym)
      return @svc.send(sym)
    end

    def handle_item(item)
      return @svc.upsert_webhook_body(item)
    end

    def fetch_backfill_page(pagination_token, last_backfilled:)
      return @svc._fetch_backfill_page(pagination_token, last_backfilled:)
    rescue ::Timeout::Error, ::SocketError => e
      self.__retryordie(e)
    rescue Webhookdb::Http::Error => e
      self.__retryordie(e) if e.status >= 500
      raise
    end

    def __retryordie(e)
      raise Amigo::Retry::OrDie.new(self.server_error_retries, self.server_error_backoff, e)
    end
  end

  # Called when the upstream dependency upserts. In most cases, you can noop;
  # but in some cases, you may want to update or fetch rows.
  # One example would be a 'db only' integration, where values are taken from the parent service
  # and added to this service's table. We may want to upsert rows in our table
  # whenever a row in our parent table changes.
  #
  # @param replicator [Webhookdb::Replicator::Base]
  # @param payload [Hash]
  # @param changed [Boolean]
  def on_dependency_webhook_upsert(replicator, payload, changed:)
    raise NotImplementedError, "this must be overridden for replicators that have dependencies"
  end

  def calculate_dependency_state_machine_step(dependency_help:)
    raise Webhookdb::InvalidPrecondition, "#{self.descriptor.name} does not have a dependency" if
      self.class.descriptor.dependency_descriptor.nil?
    return nil if self.service_integration.depends_on_id
    step = Webhookdb::Replicator::StateMachineStep.new
    dep_descr = self.descriptor.dependency_descriptor
    candidates = self.service_integration.dependency_candidates
    if candidates.empty?
      step.output = %(This integration requires #{dep_descr.resource_name_plural} to sync.

You don't have any #{dep_descr.resource_name_singular} integrations yet. You can run:

  webhookdb integrations create #{dep_descr.name}

to set one up. Then once that's complete, you can re-run:

  webhookdb integrations create #{self.descriptor.name}

to keep going.
)
      step.error_code = "no_candidate_dependency"
      return step.completed
    end
    choice_lines = candidates.each_with_index.
      map { |si, idx| "#{idx + 1} - #{si.table_name}" }.
      join("\n")
    step.output = %(This integration requires #{dep_descr.resource_name_plural} to sync.
#{"\n#{dependency_help}\n" unless dependency_help.blank?}
Enter the number for the #{dep_descr.resource_name_singular} integration you want to use,
or leave blank to choose the first option.

#{choice_lines}
)
    step.prompting("Parent integration number")
    step.post_to_url = self.service_integration.authed_api_path + "/transition/dependency_choice"
    return step
  end

  def webhook_endpoint
    return self._webhook_endpoint
  end

  # Avoid writes under the following conditions:
  #
  # - A table lock is taken on the table
  # - A vacuum is in progress on the table
  #
  # Of course, in most situations we want to write anyway,
  # but there are some cases (lower-priority replicators for example)
  # where we can reschedule the job to happen in the future instead.
  def avoid_writes?
    # We will need to handle this differently when not under Postgres, but for now,
    # just assume Postgres.
    # Find the admin URL for the organization's server (NOT the organization admin url, it can't see system processes).
    # Then check for 1) vacuums in progress, 2) locks.
    self.service_integration.organization.readonly_connection do |db|
      count = db[:pg_locks].
        join(:pg_class, {oid: :relation}).
        join(:pg_namespace, {oid: :relnamespace}).
        where(
          locktype: "relation",
          nspname: self.service_integration.organization.replication_schema,
          relname: self.service_integration.table_name,
          mode: ["ShareUpdateExclusiveLock", "ExclusiveLock", "AccessExclusiveLock"],
        ).select(1).limit(1).first
      return true if count.present?
    end
    return false
  end

  protected def _webhook_endpoint
    return self.service_integration.unauthed_webhook_endpoint
  end

  protected def _backfill_command
    return "webhookdb backfill #{self.service_integration.opaque_id}"
  end

  protected def _query_help_output(prefix: "You can query the table")
    sint = self.service_integration
    return %(#{prefix} through your organization's Postgres connection string:

  psql #{sint.organization.readonly_connection_url}
  > SELECT * FROM #{sint.table_name}

You can also run a query through the CLI:

  webhookdb db sql "SELECT * FROM #{sint.table_name}"
  )
  end
end
