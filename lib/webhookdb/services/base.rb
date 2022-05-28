# frozen_string_literal: true

require "webhookdb/backfiller"
require "webhookdb/db_adapter"
require "webhookdb/connection_cache"
require "webhookdb/services/column"
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

  # @return [Symbol]
  def table_sym
    return self.service_integration.table_name.to_sym
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

  def create_table
    cmd = self.create_table_sql
    self.admin_dataset do |ds|
      ds.db << cmd
    end
  end

  # @return [String]
  def create_table_sql
    table = Webhookdb::DBAdapter::Table.new(name: self.table_sym)
    columns = [self.primary_key_column, self.remote_key_column]
    columns.concat(self.denormalized_columns)
    # 'data' column should be last, since it's very large, we want to see other columns in psql/pgcli first
    columns << self.data_column
    adapter = Webhookdb::DBAdapter::PG.new
    lines = [adapter.create_table_sql(table, columns)]
    columns.filter(&:index?).each do |col|
      dbindex = Webhookdb::DBAdapter::Index.new(name: "#{col.name}_idx".to_sym, table:, targets: [col])
      lines << adapter.create_index_sql(dbindex)
    end
    self._enrichment_tables_descriptors.each do |tdesc|
      lines << adapter.create_table_sql(tdesc.table, tdesc.columns)
      tdesc.indices.each { |ind| lines << adapter.create_index_sql(ind) }
    end
    return lines.join(";\n") + ";"
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

  # @return [Array<Webhookdb::DBAdapter::Column>]
  def denormalized_columns
    return self._denormalized_columns.map(&:to_dbadapter)
  end

  # @return [Array<Webhookdb::DBAdapter::TableDescriptor>]
  def _enrichment_tables_descriptors
    return []
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
    stmt = self.ensure_all_columns_sql
    return if stmt.blank?
    self.admin_dataset do |ds|
      ds.db << stmt
      # We need to clear cached columns on the data since we know we're adding more.
      # It's probably not a huge deal but may as well keep it in sync.
      ds.send(:clear_columns_cache)
    end
    self.readonly_dataset { |ds| ds.send(:clear_columns_cache) }
  end

  def ensure_all_columns_sql
    self.admin_dataset do |ds|
      return self.create_table_sql unless ds.db.table_exists?(self.table_sym)
      existing_cols = ds.columns
      missing_columns = self._denormalized_columns.delete_if { |c| existing_cols.include?(c.name) }
      adapter = Webhookdb::DBAdapter::PG.new
      table = Webhookdb::DBAdapter::Table.new(name: self.table_sym)
      lines = []
      missing_columns.each do |whcol|
        # Don't bother bulking the ADDs into a single ALTER TABLE,
        # it won't really matter.
        col = whcol.to_dbadapter
        lines << adapter.add_column_sql(table, col)
        if col.index?
          index = Webhookdb::DBAdapter::Index.new(name: "#{col.name}_idx".to_sym, table:, targets: [col])
          lines << adapter.create_index_sql(index)
        end
      end
      result = lines.join(";\n")
      return result.empty? ? "" : result + ";"
    end
  end

  def upsert_webhook(body:)
    remote_key_col = self._remote_key_column
    enrichment = self._fetch_enrichment(body)
    prepared = self._prepare_for_insert(body, enrichment:)
    return nil if prepared.nil?
    inserting = {}
    # Only put the data in here if we're not replacing it,
    # to avoid the extra to_json call.
    inserting[:data] = body.to_json unless prepared.key?(:data)
    inserting.merge!(prepared)
    updating = self._upsert_update_expr(inserting, enrichment:)
    update_where = self._update_where_expr
    upserted_rows = self.admin_dataset do |ds|
      ds.insert_conflict(
        target: remote_key_col.name,
        update: updating,
        update_where:,
      ).insert(inserting)
    end
    row_changed = upserted_rows.present?
    self._after_insert(inserting, enrichment:)
    self._notify_dependents(inserting, row_changed)
    return unless row_changed
    self._publish_rowupsert(inserting)
  end

  def _notify_dependents(inserting, changed)
    self.service_integration.dependents.each do |d|
      d.service_instance.on_dependency_webhook_upsert(self, inserting, changed:)
    end
  end

  def _publish_rowupsert(row)
    return if self.service_integration.all_webhook_subscriptions_dataset.to_notify.empty?
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

  # Given a webhook body that is going to be inserted,
  # make an optional API call to enrich it with further data.
  # The result of this is passed to _prepare_for_insert
  # and _after_insert.
  # @return [*]
  def _fetch_enrichment(_body)
    return nil
  end

  # After an insert is done, do any additional processing
  # on other tables. Useful when we have to maintain 'enrichment tables'
  # for a resource that have things that aren't useful in a single row,
  # like time-series data.
  # @return [*]
  def _after_insert(_inserting, enrichment:)
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

  # Given the webhook headers and body, return a hash of what will be inserted.
  # It must include the key column and all denormalized columns.
  #
  # If this returns nil, the upsert is skipped.
  #
  # @abstract
  # @return [Hash]
  def _prepare_for_insert(body, enrichment: nil)
    raise NotImplementedError
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

  # @return [Sequel::Dataset]
  def admin_dataset(&)
    self.with_dataset(self.service_integration.organization.admin_connection_url_raw, &)
  end

  # @return [Sequel::Dataset]
  def readonly_dataset(&)
    self.with_dataset(self.service_integration.organization.readonly_connection_url_raw, &)
  end

  protected def with_dataset(url, &block)
    raise LocalJumpError if block.nil?
    Webhookdb::ConnectionCache.borrow(url) do |conn|
      yield(conn[self.table_sym])
    end
  end

  class CredentialVerificationResult < Webhookdb::TypedStruct
    attr_reader :verified, :message
  end

  # @return [Webhookdb::CredentialVerificationResult]
  def verify_backfill_credentials
    begin
      # begin backfill attempt but do not return backfill result
      _backfill = self._fetch_backfill_page(nil, last_backfilled: nil)
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
    last_backfilled = incremental ? self.service_integration.last_backfilled_at : nil
    raise Webhookdb::Services::CredentialsMissing if
      self.service_integration.backfill_key.blank? && self.service_integration.backfill_secret.blank?
    new_last_backfilled = Time.now
    ServiceBackfiller.new(self).backfill(last_backfilled)
    self.service_integration.update(last_backfilled_at: new_last_backfilled) if incremental
    return unless cascade
    self.service_integration.dependents.each do |dep|
      Webhookdb.publish(
        "webhookdb.serviceintegration.backfill", dep.id,
      )
    end
  end

  def _fetch_backfill_page(pagination_token, last_backfilled:)
    raise NotImplementedError
  end

  class ServiceBackfiller < Webhookdb::Backfiller
    # @!attribute svc
    #   @return [Webhookdb::Services::Base]

    def initialize(svc)
      @svc = svc
      super()
    end

    def handle_item(item)
      return @svc.upsert_webhook(body: item)
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
