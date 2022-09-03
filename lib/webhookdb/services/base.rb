# frozen_string_literal: true

require "webhookdb/backfiller"
require "webhookdb/db_adapter"
require "webhookdb/connection_cache"
require "webhookdb/services/column"
require "webhookdb/services/schema_modification"
require "webhookdb/typed_struct"

require "webhookdb/jobs/send_webhook"

class Webhookdb::Services::Base
  include Webhookdb::DBAdapter::ColumnTypes

  # @return [Webhookdb::Services::Descriptor]
  def self.descriptor
    raise NotImplementedError, "each service must return a descriptor that is used for registration purposes"
  end

  # @return [Webhookdb::ServiceIntegration]
  attr_reader :service_integration

  def initialize(service_integration)
    @service_integration = service_integration
  end

  # @return [Webhookdb::Services::Descriptor]
  def descriptor
    return @descriptor ||= self.class.descriptor
  end

  def resource_name_singular
    return @resource_name_singular ||= self.descriptor.resource_name_singular
  end

  def resource_name_plural
    return @resource_name_plural ||= self.descriptor.resource_name_plural
  end

  # @return [Array<Symbol>]
  def schema_and_table_symbols
    sch = self.service_integration.organization&.replication_schema&.to_sym || :public
    tbl = self.service_integration.table_name.to_sym
    return [sch, tbl]
  end

  # Return a Sequel identifier using +schema_and_table_symbols+,
  # or +schema+ or +table+ as overrides if given.
  # @return [Sequel::SQL::QualifiedIdentifier]
  def qualified_table_sequel_identifier(schema: nil, table: nil)
    sch, tbl = self.schema_and_table_symbols
    return Sequel[schema || sch][table || tbl]
  end

  # @return [Webhookdb::DBAdapter::Table]
  def dbadapter_table
    sch, tbl = self.schema_and_table_symbols
    schema = Webhookdb::DBAdapter::Schema.new(name: sch)
    table = Webhookdb::DBAdapter::Table.new(name: tbl, schema:)
    return table
  end

  # Time.at(t), but nil if t is nil.
  # Use when we have 'nullable' integer timestamps.
  # @return [Time]
  protected def tsat(t)
    return nil if t.nil?
    return Time.at(t)
  end

  # @return [Webhookdb::WebhookResponse]
  def webhook_response(request)
    return Webhookdb::WebhookResponse.ok(status: 201) if self.service_integration.skip_webhook_verification
    return self._webhook_response(request)
  end

  # Return a the response for the webhook.
  # We must do this immediately in the endpoint itself,
  # since verification may include info specific to the request content
  # (like, it can be whitespace sensitive).
  # @return [Webhookdb::WebhookResponse]
  def _webhook_response(request)
    raise NotImplementedError
  end

  # Set the new service integration field and
  # return the newly calculated state machine.
  #
  # Subclasses can override this method and then super,
  # to change the field or value.
  #
  # @param field [String]
  # @param value [String]
  # @return [Webhookdb::Services::StateMachineStep]
  def process_state_change(field, value)
    case field
      when "webhook_secret"
        meth = :calculate_create_state_machine
      when "backfill_key", "backfill_secret", "api_url"
        meth = :calculate_backfill_state_machine
      when "dependency_choice"
        meth = :calculate_create_state_machine
        value = self._find_dependency_candidate(value)
        field = "depends_on"
      else
        raise ArgumentError, "Field '#{field}' is not valid for a state change"
    end
    self.service_integration.db.transaction do
      self.service_integration.send("#{field}=", value)
      self.service_integration.save_changes
      return self.send(meth)
    end
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

  # @return [Webhookdb::Services::StateMachineStep]
  def calculate_create_state_machine
    # This is a pure function that can be tested on its own--the endpoints just need to return a state machine step
    raise NotImplementedError
  end

  # @return [Webhookdb::Services::StateMachineStep]
  def calculate_backfill_state_machine
    # This is a pure function that can be tested on its own--the endpoints just need to return a state machine step
    raise NotImplementedError
  end

  # Remove all the information used in the initial creation of the integration so that it can be re-entered
  def clear_create_information
    self.service_integration.update(webhook_secret: "")
  end

  # Remove all the information needed for backfilling from the integration so that it can be re-entered
  def clear_backfill_information
    self.service_integration.update(api_url: "", backfill_key: "", backfill_secret: "")
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

  # @return [Webhookdb::Services::SchemaModification]
  def create_table_modification(if_not_exists: false)
    table = self.dbadapter_table
    columns = [self.primary_key_column, self.remote_key_column]
    columns.concat(self.storable_columns)
    # 'data' column should be last, since it's very large, we want to see other columns in psql/pgcli first
    columns << self.data_column
    adapter = Webhookdb::DBAdapter::PG.new
    result = Webhookdb::Services::SchemaModification.new
    result.transaction_statements << adapter.create_table_sql(table, columns, if_not_exists:)
    columns.select(&:index?).each do |col|
      dbindex = Webhookdb::DBAdapter::Index.new(name: self.index_name(col).to_sym, table:, targets: [col])
      result.transaction_statements << adapter.create_index_sql(dbindex, concurrently: false)
    end
    return result
  end

  # We need to give indices a persistent name, unique across the schema,
  # since multiple indices within a schema cannot share a name.
  # @param column DBAdapter or Services Column (must have :name).
  # @return [String]
  protected def index_name(column)
    raise Webhookdb::InvalidPrecondition, "sint needs an opaque id" if self.service_integration.opaque_id.blank?
    return "#{self.service_integration.opaque_id}_#{column.name}_idx"
  end

  # @return [Webhookdb::DBAdapter::Column]
  def primary_key_column
    return Webhookdb::DBAdapter::Column.new(name: :pk, type: BIGINT, pk: true)
  end

  # @return [Webhookdb::DBAdapter::Column]
  def remote_key_column
    return self._remote_key_column.to_dbadapter(unique: true, nullable: false)
  end

  # @return [Webhookdb::DBAdapter::Column]
  def data_column
    return Webhookdb::DBAdapter::Column.new(name: :data, type: OBJECT, nullable: false)
  end

  # Column used to store enrichments. Return nil if the service does not use enrichments.
  # @return [Webhookdb::DBAdapter::Column]
  def enrichment_column
    return nil unless self._store_enrichment_body?
    return Webhookdb::DBAdapter::Column.new(name: :enrichment, type: OBJECT, nullable: true)
  end

  # @return [Array<Webhookdb::DBAdapter::Column>]
  def denormalized_columns
    return self._denormalized_columns.map(&:to_dbadapter)
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

  def _timestamp_column_name
    raise NotImplementedError
  end

  # Each integration needs a single remote key, like the Shopify order id for shopify orders,
  # or sid for Twilio resources. This column must be unique for the table.
  #
  # @abstract
  # @return [Webhookdb::Services::Column]
  def _remote_key_column
    raise NotImplementedError
  end

  # When an integration needs denormalized columns, specify them here.
  # Indices are created for each column.
  # Modifiers can be used if columns should have a default or whatever.
  #
  # @return [Array<Webhookdb::Services::Column]
  def _denormalized_columns
    return []
  end

  # We support adding columns to existing integrations without having to bump the version;
  # changing types, or removing/renaming columns, is not supported and should bump the version
  # or must be handled out-of-band (like deleting the integration then backfilling).
  # To figure out what columns we need to add, we can check what are currently defined,
  # check what exists, and add denormalized columns and indices for those that are missing.
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

  # @return [Webhookdb::Services::SchemaModification]
  def ensure_all_columns_modification
    existing_cols, existing_indices = nil
    self.admin_dataset do |ds|
      return self.create_table_modification unless ds.db.table_exists?(self.qualified_table_sequel_identifier)
      existing_cols = ds.columns.to_set
      sint = self.service_integration
      existing_indices = ds.db[:pg_indexes].where(
        schemaname: sint.organization.replication_schema,
        tablename: sint.table_name,
      ).select_map(:indexname).to_set
    end
    adapter = Webhookdb::DBAdapter::PG.new
    table = self.dbadapter_table
    result = Webhookdb::Services::SchemaModification.new

    missing_columns = self._denormalized_columns.delete_if { |c| existing_cols.include?(c.name) }
    unless missing_columns.empty?
      # Add missing columns, and an UPDATE to fill in the defaults.
      missing_columns.each do |whcol|
        # Don't bother bulking the ADDs into a single ALTER TABLE, it won't really matter.
        result.transaction_statements << adapter.add_column_sql(table, whcol.to_dbadapter)
      end
      self.admin_dataset do |ds|
        update_query = ds.update_sql(missing_columns.to_h { |col| [col.name, col.to_sql_expr] })
        result.transaction_statements << update_query
      end
    end
    # Easier to handle this explicitly than use storage_columns, but it a duplicated concept so be careful.
    if (enrich_col = self.enrichment_column) && !existing_cols.include?(enrich_col.name)
      result.transaction_statements << adapter.add_column_sql(table, enrich_col)
    end

    # Add missing indices
    self._denormalized_columns.select(&:index?).map do |col|
      idx_name = self.index_name(col)
      next if existing_indices.include?(idx_name)
      index = Webhookdb::DBAdapter::Index.new(name: idx_name.to_sym, table:, targets: [col])
      result.nontransaction_statements << adapter.create_index_sql(index, concurrently: true)
    end
    return result
  end

  # A given HTTP request may not be handled by the service integration it was sent to,
  # for example where the service integration is part of some 'root' hierarchy.
  # This method is called in the webhook endpoint, and should return the service instance
  # used to handle the webhook request. The request is validated by the returned instance,
  # and it is enqueued for processing.
  #
  # By default, the service called by the webhook is the one we want to use,
  # so return self.
  #
  # @param request [Rack::Request]
  # @return [Webhookdb::Services::Base]
  def dispatch_request_to(request)
    return self
  end

  # Upsert webhook using only a body.
  # This is not valid for the rare integration which does not rely on request info,
  # like when we have to take different action based on a request method.
  def upsert_webhook_body(body)
    return self.upsert_webhook(body:, headers: nil, request_path: nil, request_method: nil)
  end

  def upsert_webhook(body:, headers:, request_path:, request_method:)
    remote_key_col = self._remote_key_column
    resource, event = self._resource_and_event(body)
    return nil if resource.nil?
    enrichment = self._fetch_enrichment(resource, event)
    prepared = self._prepare_for_insert(resource, event, enrichment)
    raise Webhookdb::InvalidPostcondition if prepared.key?(:data)
    inserting = {}
    inserting[:data] = resource.to_json
    inserting[:enrichment] = enrichment.to_json if self._store_enrichment_body?
    inserting.merge!(prepared)
    updating = self._upsert_update_expr(inserting, enrichment:)
    update_where = self._update_where_expr
    upserted_rows = self.admin_dataset(timeout: :fast) do |ds|
      ds.insert_conflict(
        target: remote_key_col.name,
        update: updating,
        update_where:,
      ).insert(inserting)
    end
    row_changed = upserted_rows.present?
    self._notify_dependents(inserting, row_changed)
    return unless row_changed
    self._publish_rowupsert(inserting)
  end

  def _notify_dependents(inserting, changed)
    self.service_integration.dependents.each do |d|
      d.service_instance.on_dependency_webhook_upsert(self, inserting, changed:)
    end
  end

  def _any_subscriptions_to_notify?
    return !self.service_integration.all_webhook_subscriptions_dataset.to_notify.empty?
  end

  def _publish_rowupsert(row, check_for_subscriptions: true)
    return unless check_for_subscriptions && self._any_subscriptions_to_notify?
    # We AVOID pubsub here because we do NOT want to go through the router
    # and audit logger for this.
    event = Webhookdb::Event.create(
      "webhookdb.serviceintegration.rowupsert",
      [self.service_integration.id,
       {
         row:,
         external_id_column: self._remote_key_column.name,
         external_id: row[self._remote_key_column.name],
       },],
    )
    Webhookdb::Jobs::SendWebhook.perform_async(event.as_json)
  end

  # Return true if the integration requires making an API call to upsert.
  # This puts the sync into a lower-priority queue
  # so it is less likely to block other processing.
  # This is usually true if enrichments are involved.
  def upsert_has_deps?
    return false
  end

  # Given the resource that is going to be inserted and an optional event,
  # make an API call to enrich it with further data if needed.
  # The result of this is passed to _prepare_for_insert.
  # @return [*]
  def _fetch_enrichment(_resource, _event)
    return nil
  end

  # The argument for insert_conflict update_where clause.
  # Used to conditionally update, like updating only if a row is newer than what's stored.
  # We must always have an 'update where' because we never want to overwrite with the same data
  # as exists. If an integration does not have any way to detect if a resource changed,
  # it can compare data columns.
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
  # @abstract
  # @return [Array<Hash>]
  def _resource_and_event(_body)
    raise NotImplementedError
  end

  # Return the hash that should be inserted into the database,
  # based on the denormalized columns and data given.
  # @return [Hash]
  def _prepare_for_insert(resource, event, enrichment)
    h = [self._remote_key_column].concat(self._denormalized_columns).each_with_object({}) do |col, memo|
      value = col.to_ruby_converter[resource, event, enrichment]
      skip = value.nil? && col.skip_nil?
      memo[col.name] = value unless skip
    end
    return h
  end

  # Given the hash that is passed to the Sequel insert
  # (so contains all columns, including those from _prepare_for_insert),
  # return the hash used for the insert_conflict(update:) keyword args.
  # This should be used when the service requires different values for inserting
  # vs. updating, such as when a column's update value
  # must use the EXCLUDED table in the upsert expression.
  #
  # By default, this just returns inserting, and insert/update use the same values.
  def _upsert_update_expr(inserting, enrichment: nil)
    return inserting
  end

  # The string 'null' in a json column still represents 'null' but we'd rather have an actual NULL value,
  # represented by 'nil'. So, return nil if the arg is nil (so we get NULL),
  # otherwise return the argument.
  protected def _nil_or_json(x)
    return x.nil? ? nil : x.to_json
  end

  # Have a column set itself only on insert or if nil.
  #
  # Given the payload being inserted, return a new hash where
  # the column names included in 'column_names' use what is already in the table,
  # and fall back to what's being inserted.
  # This new payload should be passed to the `update` kwarg of `insert_conflict`:
  #
  # ds.insert_conflict(update: self._coalesce_excluded_on_update(payload, :created_at)).insert(payload)
  #
  # @param inserting [Hash]
  # @param column_names [Array<Symbol>]
  def _coalesce_excluded_on_update(inserting, column_names)
    result = inserting.dup
    column_names.each do |c|
      result[c] = Sequel.function(:coalesce, self.qualified_table_sequel_identifier[c], Sequel[:excluded][c])
    end
    return result
  end

  # @return [Sequel::Dataset]
  def admin_dataset(**kw, &)
    self.with_dataset(self.service_integration.organization.admin_connection_url_raw, **kw, &)
  end

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

  class CredentialVerificationResult < Webhookdb::TypedStruct
    attr_reader :verified, :message
  end

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
      msg = if self.respond_to?("_verify_backfill_#{e.status}_err_msg")
              self.send("_verify_backfill_#{e.status}_err_msg")
      else
        self._verify_backfill_err_msg
      end
      return CredentialVerificationResult.new(verified: false, message: msg)
    rescue TypeError, NoMethodError => e
      # if we don't incur an HTTP error, but do incur an Error due to differences in the shapes of anticipated
      # response data in the `fetch_backfill_page` function, we can assume that the credentials are okay
      self.logger.info "verify_backfill_credentials_expected_failure", error: e
      return CredentialVerificationResult.new(verified: true, message: "")
    end
    return CredentialVerificationResult.new(verified: true, message: "")
  end

  def _verify_backfill_err_msg
    raise NotImplementedError, "each integration must provide an error message for unanticipated errors"
  end

  # In order to backfill, we need to:
  # - Iterate through pages of records from the external service
  # - Upsert each record
  # The caveats/complexities are:
  # - The backfill method should take care of retrying fetches for failed pages.
  # - That means it needs to keep track of some pagination token.
  def backfill(incremental: false, cascade: false)
    sint = self.service_integration
    last_backfilled = incremental ? sint.last_backfilled_at : nil
    raise Webhookdb::Services::CredentialsMissing if
      sint.backfill_key.blank? && sint.backfill_secret.blank? && sint.depends_on.blank?
    new_last_backfilled = Time.now

    self._backfillers.each do |backfiller|
      backfiller.backfill(last_backfilled)
    end

    sint.update(last_backfilled_at: new_last_backfilled) if incremental
    return unless cascade
    sint.dependents.each do |dep|
      Webhookdb.publish(
        "webhookdb.serviceintegration.backfill", dep.id, {cascade: true, incremental:},
      )
    end
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

  class ServiceBackfiller < Webhookdb::Backfiller
    # @!attribute svc
    #   @return [Webhookdb::Services::Base]

    def initialize(svc)
      @svc = svc
      raise "#{svc} must implement :_fetch_backfill_page" unless svc.respond_to?(:_fetch_backfill_page)
      super()
    end

    def handle_item(item)
      return @svc.upsert_webhook_body(item)
    end

    def fetch_backfill_page(pagination_token, last_backfilled:)
      return @svc._fetch_backfill_page(pagination_token, last_backfilled:)
    end
  end

  # @param service_instance [Webhookdb::Services::Base]
  # @param payload [Hash]
  # @param changed [Boolean]
  def on_dependency_webhook_upsert(service_instance, payload, changed:)
    raise NotImplementedError, "this must be overridden for services that have dependencies"
  end

  def calculate_dependency_state_machine_step(dependency_help:)
    raise Webhookdb::InvalidPrecondition, "#{self.descriptor.name} does not have a dependency" if
      self.class.descriptor.dependency_descriptor.nil?
    return nil if self.service_integration.depends_on_id
    step = Webhookdb::Services::StateMachineStep.new
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
#{dependency_help.blank? ? '' : "\n#{dependency_help}\n"}
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

  protected def _webhook_endpoint
    return "#{Webhookdb.api_url}#{self.service_integration.unauthed_webhook_path}"
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
