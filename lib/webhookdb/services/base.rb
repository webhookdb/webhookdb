# frozen_string_literal: true

require "webhookdb/connection_cache"
require "webhookdb/services/column"

class Webhookdb::Services::Base
  # @return [Webhookdb::ServiceIntegration]
  attr_reader :service_integration

  def initialize(service_integration)
    @service_integration = service_integration
  end

  def table_sym
    return self.service_integration.table_name.to_sym
  end

  # Return a [status, headers, body] triple of the response for the webhook.
  # By default, if the webhook is not verified, we return a 401, otherwise we return success.
  # If the webhook needs extra validation or behavior (like Twilio requires special headers),
  # you can override this entirely and not bother overriding `_webhook_verified?`.
  def webhook_response(request)
    return [202, {"Content-Type" => "text/plain"}, "ok"] if self._webhook_verified?(request)
    return [401, {"Content-Type" => "text/plain"}, ""]
  end

  # Set the new service integration field and
  # return the newly calculated state machine.
  #
  # Subclasses can override this method and then super,
  # to change the field or value.
  #
  # @return [Webhookdb::Services::StateMachineStep]
  def process_state_change(field, value)
    self.service_integration.db.transaction do
      self.service_integration.send("#{field}=", value)
      self.service_integration.save_changes
      case field
        when "webhook_secret"
          return self.calculate_create_state_machine
        when "backfill_key", "backfill_secret", "api_url"
          return self.calculate_backfill_state_machine
        else
          return
      end
    end
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

  # Check if the webhook is verified using the http request.
  # We must do this immediately in the endpoint itself,
  # since verification may include info specific to the request content
  # (like, it can be whitespace sensitive).
  #
  # @return [Boolean] if the webhook is verified.
  def _webhook_verified?(request)
    raise NotImplementedError
  end

  def create_table
    cmd = self._create_table_sql
    self.admin_dataset do |ds|
      ds.db << cmd
    end
  end

  def create_table_sql
    return self._create_table_sql
  end

  def _create_table_sql
    tbl = self.service_integration.table_name
    remote_key_col = self._remote_key_column
    denormalized_columns = self._denormalized_columns
    lines = [
      "CREATE TABLE #{tbl} (",
      "  pk bigserial PRIMARY KEY,",
      +"  \"#{remote_key_col.name}\" #{remote_key_col.type} UNIQUE NOT NULL",
    ]
    denormalized_columns.each do |col|
      lines.last << ","
      lines << +"  \"#{col.name}\" #{col.type} #{col.modifiers}"
    end
    # noinspection RubyModifiedFrozenObject
    lines.last << ","
    # 'data' column should be last, since it's very large, we want to see other columns in psql/pgcli first
    lines << "  data jsonb NOT NULL"
    lines << ");"
    denormalized_columns.each do |col|
      lines << "CREATE INDEX IF NOT EXISTS #{col.name}_idx ON #{tbl} (\"#{col.name}\");"
    end
    if (enrichment_sql = self._create_enrichment_tables_sql).present?
      lines << enrichment_sql
    end
    return lines.join("\n")
  end

  def _create_enrichment_tables_sql
    return ""
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
      return self._create_table_sql unless ds.db.table_exists?(self.table_sym)
      existing_cols = ds.columns
      missing_columns = self._denormalized_columns.delete_if { |c| existing_cols.include?(c.name) }
      tbl = self.table_sym
      lines = []
      missing_columns.each do |col|
        # There's some duplication here with the create SQL,
        # but it's so minimal and rote as not to matter.
        # Don't bother bulking the ADDs into a single ALTER TABLE,
        # it won't really matter.
        lines << "ALTER TABLE #{tbl} ADD \"#{col.name}\" #{col.type} #{col.modifiers};"
        lines << "CREATE INDEX IF NOT EXISTS #{col.name}_idx ON #{tbl} (\"#{col.name}\");"
      end
      return lines.join("\n")
    end
  end

  def upsert_webhook(body:)
    remote_key_col = self._remote_key_column
    enrichment = self._fetch_enrichment(body)
    prepared = self._prepare_for_insert(body, enrichment: enrichment)
    return nil if prepared.nil?
    inserting = {data: body.to_json}
    inserting.merge!(prepared)
    updating = self._upsert_update_expr(inserting, enrichment: enrichment)
    update_where = self._update_where_expr
    self.admin_dataset do |ds|
      ds.insert_conflict(
        target: remote_key_col.name,
        update: updating,
        update_where: update_where,
      ).insert(inserting)
    end
    self._after_insert(inserting, enrichment: enrichment)
  end

  # Given a webhook body that is going to be inserted,
  # make an optional API call to enrich it with further data.
  # The result of this is passed to _prepare_for_insert
  # and _after_insert.
  def _fetch_enrichment(_body)
    return nil
  end

  # After an insert is done, do any additional processing
  # on other tables. Useful when we have to maintain 'enrichment tables'
  # for a resource that have things that aren't useful in a single row,
  # like time-series data.
  def _after_insert(_inserting, enrichment:)
    return nil
  end

  # Upsert a backfill payload into the database.
  # By default, assume the webhook and backfill payload are the same shape
  # and just use upsert_webhook(body: payload).
  def upsert_backfill_payload(payload)
    self.upsert_webhook(body: payload)
  end

  # The argument for insert_conflict update_where clause.
  # Used to conditionally update, like updating only if a row is newer than what's stored.
  def _update_where_expr
    return nil
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

  def admin_dataset(&block)
    self.with_dataset(self.service_integration.organization.admin_connection_url, &block)
  end

  def readonly_dataset(&block)
    self.with_dataset(self.service_integration.organization.readonly_connection_url, &block)
  end

  protected def with_dataset(url, &block)
    raise LocalJumpError if block.nil?
    Webhookdb::ConnectionCache.borrow(url) do |conn|
      yield(conn[self.table_sym])
    end
  end

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
      return {verified: false, message: msg}
    rescue TypeError, NoMethodError => e
      # if we don't incur an HTTP error, but do incur an Error due to differences in the shapes of anticipated
      # response data in the `fetch_backfill_page` function, we can assume that the credentials are okay
      self.logger.info "verify_backfill_credentials_expected_failure", error: e
      return {verified: true, message: ""}
    end
    return {verified: true, message: ""}
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
  def backfill(incremental: false)
    last_backfilled = incremental ? self.service_integration.last_backfilled_at : nil
    raise Webhookdb::Services::CredentialsMissing if
      self.service_integration.backfill_key.blank? && self.service_integration.backfill_secret.blank?
    pagination_token = nil
    new_last_backfilled = Time.now
    loop do
      page, next_pagination_token = self._fetch_backfill_page_with_retry(
        pagination_token, last_backfilled: last_backfilled,
      )
      pagination_token = next_pagination_token
      page.each do |item|
        self.upsert_webhook(body: item)
      end
      break if pagination_token.blank?
    end
    self.service_integration.update(last_backfilled_at: new_last_backfilled) if incremental
  end

  def max_backfill_retry_attempts
    return 3
  end

  def wait_for_retry_attempt(attempt:)
    return sleep(attempt)
  end

  def _fetch_backfill_page_with_retry(pagination_token, last_backfilled: nil, attempt: 1)
    return self._fetch_backfill_page(pagination_token, last_backfilled: last_backfilled)
  rescue RuntimeError => e
    raise e if attempt >= self.max_backfill_retry_attempts
    self.wait_for_retry_attempt(attempt: attempt)
    return self._fetch_backfill_page_with_retry(pagination_token, last_backfilled: last_backfilled,
                                                                  attempt: attempt + 1,)
  end

  def _fetch_backfill_page(pagination_token, last_backfilled:)
    raise NotImplementedError
  end

  protected def _webhook_endpoint
    return "#{Webhookdb.api_url}/v1/service_integrations/#{self.service_integration.opaque_id}"
  end

  protected def _backfill_command
    return "webhookdb backfill #{self.service_integration.opaque_id}"
  end

  protected def _query_help_output
    sint = self.service_integration
    return %(You can query the table through your organization's Postgres connection string:

  psql #{sint.organization.readonly_connection_url}
  > SELECT * FROM #{sint.table_name}

You can also run a query through the CLI:

  webhookdb db sql "SELECT * FROM #{sint.table_name}"
  )
  end
end
