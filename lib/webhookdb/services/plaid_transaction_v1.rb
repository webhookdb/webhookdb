# frozen_string_literal: true

require "webhookdb/async/job"
require "webhookdb/backfiller"
require "webhookdb/crypto"
require "webhookdb/plaid"

class Webhookdb::Services::PlaidTransactionV1 < Webhookdb::Services::Base
  include Appydays::Loggable

  # @return [Webhookdb::Services::Descriptor]
  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "plaid_transaction_v1",
      ctor: Webhookdb::Services::PlaidTransactionV1,
      feature_roles: ["beta"],
      resource_name_singular: "Plaid Transaction",
      dependency_descriptor: Webhookdb::Services::PlaidItemV1.descriptor,
    )
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:plaid_id, TEXT, data_key: "transaction_id")
  end

  def _denormalized_columns
    return [
      # Item Id is populated from the backfiller instance here, so we use a dummy key and replace it later
      Webhookdb::Services::Column.new(:item_id, TEXT, index: true, data_key: "ignore_id", optional: true),
      Webhookdb::Services::Column.new(:account_id, TEXT, index: true),
      Webhookdb::Services::Column.new(:amount, TEXT),
      Webhookdb::Services::Column.new(:iso_currency_code, TEXT),
      Webhookdb::Services::Column.new(:date, DATE, index: true),
      Webhookdb::Services::Column.new(:removed_at, TIMESTAMP, optional: true),
      Webhookdb::Services::Column.new(
        :row_created_at,
        TIMESTAMP,
        index: true,
        optional: true,
        defaulter: :now,
      ),
      Webhookdb::Services::Column.new(:row_updated_at, TIMESTAMP, index: true, optional: true, defaulter: :now),
    ]
  end

  def _timestamp_column_name
    return :row_updated_at
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:row_updated_at] < Sequel[:excluded][:row_updated_at]
  end

  def upsert_has_deps?
    return true
  end

  # In Plaid, webhooks are about notifications, not resources,
  # so the way we handle webhooks does not work for them.
  # Normally we'd do something like be backfill-only,
  # but we MUST handle Plaid Transaction webhooks because we do not
  # want to initiate our own backfills, as they cost customers money.
  def upsert_webhook(body:, **_kwargs)
    return unless body.fetch("webhook_type") == "TRANSACTIONS"
    item_id = body.fetch("item_id")
    plaid_item_service = self.service_integration.depends_on.service_instance
    plaid_item_row = plaid_item_service.readonly_dataset(timeout: :fast) { |ds| ds[plaid_id: item_id] }
    if plaid_item_row.nil?
      return if Webhookdb.regression_mode
      raise Webhookdb::InvalidPrecondition,
            "could not find Plaid item #{item_id} for integration #{self.service_integration.opaque_id}"
    end
    self.backfill_plaid_item(plaid_item_service, plaid_item_row)
  end

  def _webhook_response(_request)
    raise NotImplementedError, "this integration does not verify webhooks (it should come through plaid items)"
  end

  def calculate_create_state_machine
    if (step = self.calculate_dependency_state_machine_step(dependency_help: ""))
      return step
    end
    step = Webhookdb::Services::StateMachineStep.new
    step.output = %(Great! If you have fully set up your Plaid Items integration,
including setting the 'webhook' parameter when you create Link tokens,
and updating existing items in Plaid to point to your webhook URL,
you are all set. If you have not, or you're not sure,
please check out https://webhookdb.com/docs/plaid for more detailed instructions.

#{self._query_help_output(prefix: 'Once data is available, you can query Plaid Transactions')})
    return step.completed
  end

  def calculate_backfill_state_machine
    step = Webhookdb::Services::StateMachineStep.new
    step.needs_input = false
    step.output = %(We cannot backfill Plaid Transactions because it would hit Plaid for every single
Plaid Item you have in WebhookDB, and could incur significant financial cost to your Plaid account.
Instead, you can send WebhookDB a webhook to start a backfill for specific Plaid Items.

Please refer to https://webhookdb.com/docs/plaid#backfill-history for more detailed instructions.

#{self._query_help_output(prefix: 'Once data is available, you can query the Plaid Transactions table')})
    step.error_code = "plaid_transaction_nobackfill"
    step.complete = true
    return step
  end

  def on_dependency_webhook_upsert(_service_instance, _payload, *)
    # We do not want to automatically get transactions,
    # since it would cost the customer money.
    # However we do need to override this.
    return
  end

  # @param plaid_item_service [Webhookdb::Services::PlaidItemV1]
  # @param plaid_item_row [Hash<Symbol, Any>]
  def backfill_plaid_item(plaid_item_service, plaid_item_row)
    item_integration = plaid_item_service.service_integration
    raise Webhookdb::Services::CredentialsMissing if
      item_integration.backfill_key.blank? ||
        item_integration.backfill_secret.blank? ||
        item_integration.api_url.blank?

    plaid_access_token = plaid_item_service.decrypt_item_row_access_token(plaid_item_row)

    url = self.service_integration.organization.admin_connection_url_raw
    plaid_item_id = plaid_item_row.fetch(:plaid_id)
    sync_cursor = plaid_item_row.fetch(:transaction_sync_next_cursor)
    # Slow due to bulk upsert, it could in theory take a while
    Webhookdb::ConnectionCache.borrow(url, timeout: :slow) do |conn|
      # Use the Plaid sync endpoint to increment through pages of transactions,
      # and upsert (or update in the case of remove) each transaction.
      # Because transaction backfilling can include many writers
      # for the table, we need to be careful about batching updates.
      backfiller = TransactionBackfiller.new(
        conn:,
        item_svc: plaid_item_service,
        transaction_svc: self,
        plaid_item_id:,
        plaid_access_token:,
        sync_cursor:,
      )
      # This will be unified with normal backfiller code eventually
      backfiller.backfill(nil)
      # Commit to the org DB before we update the cursor so we don't lose any changes.
      backfiller.commit
      if sync_cursor != backfiller.cursor
        conn[plaid_item_service.qualified_table_sequel_identifier].
          where(plaid_id: plaid_item_id).
          update(transaction_sync_next_cursor: backfiller.cursor)
      end
      # We may need to raise an error after we commit all changes.
      backfiller.after_commit
    end
  end

  class TransactionBackfiller < Webhookdb::Backfiller
    attr_reader :cursor

    def initialize(conn:, item_svc:, transaction_svc:, plaid_item_id:, plaid_access_token:, sync_cursor:)
      @conn = conn
      @item_svc = item_svc
      @transaction_svc = transaction_svc
      @transaction_ds = @conn[@transaction_svc.qualified_table_sequel_identifier]
      @plaid_item_id = plaid_item_id
      @plaid_access_token = plaid_access_token
      @cursor = sync_cursor
      @api_url = @item_svc.service_integration.api_url
      @temp_table = "#{@plaid_item_id}_backfill_#{SecureRandom.hex(6)}".to_sym
      @insert_row_cols = [
        :plaid_id,
        :item_id,
        :data,
        :account_id,
        :amount,
        :iso_currency_code,
        :date,
        :row_created_at,
        :row_updated_at,
      ]
      @wrote_any_rows = false
      @row_chunk = []
      @removed = []
      super()
    end

    def commit
      # Capture this so we only need to hit the DB once.
      has_to_notify = @transaction_svc._any_subscriptions_to_notify?
      # Always run this; it is done separately from the normal upsert
      self.flush_removed(notify: has_to_notify)
      self.flush_chunk
      # If we never wrote any rows, we know we have nothing to copy, nor alert.
      return unless @wrote_any_rows
      columns = [
        :plaid_id,
        :item_id,
        :data,
        :account_id,
        :amount,
        :iso_currency_code,
        :date,
        :row_created_at,
        :row_updated_at,
      ]
      update = columns.each_with_object({}).each do |c, h|
        h[c] = Sequel[:excluded][c]
      end
      update.delete(:row_created_at)
      insert_ds = @transaction_ds
      (insert_ds = insert_ds.returning) if has_to_notify
      upserted_rows = insert_ds.
        insert_conflict(target: :plaid_id, update:).
        insert(columns, @conn[@temp_table].select(*columns))
      # Only have a table to drop if we ever created the table/wrote rows.
      @conn.drop_table(@temp_table) if @wrote_any_rows
      has_to_notify && upserted_rows.each do |row|
        @transaction_svc._publish_rowupsert(row, check_for_subscriptions: false)
      end
    end

    def after_commit
      raise @retry_error if @retry_error
    end

    def handle_item(body)
      now = Time.now
      # MUST match @insert_row_columns
      inserting = [
        body.fetch("transaction_id"),
        @plaid_item_id,
        body.to_json,
        body.fetch("account_id"),
        body.fetch("amount"),
        body.fetch("iso_currency_code"),
        body.fetch("date"),
        now,
        now,
      ]
      @row_chunk << inserting
      self.flush_chunk if @row_chunk.size >= 500
    end

    def flush_removed(notify:)
      return if @removed.empty?
      now = Time.now
      @transaction_ds.where(plaid_id: @removed).update(removed_at: now, row_updated_at: now)
      notify && @transaction_ds.where(plaid_id: @removed).each do |row|
        @transaction_svc._publish_rowupsert(row)
      end
    end

    def flush_chunk
      return if @row_chunk.empty?
      # Defer the creation of the temp table until we have our first write,
      # so if our query no-ops we have nothing to do.
      unless @wrote_any_rows
        @conn.create_table(@temp_table, temp: true, as: @transaction_ds.clone(limit: 0))
        @conn.alter_table(@temp_table) { drop_column :pk }
      end
      @conn[@temp_table].import(@insert_row_cols, @row_chunk)
      @row_chunk.clear
      @wrote_any_rows = true
    end

    def fetch_backfill_page(*)
      # We ignore the token and backfill arguments since we track the backfill cursor ourselves.
      count = Webhookdb::Plaid.page_size
      url = @api_url + "/transactions/sync"
      begin
        response = Webhookdb::Http.post(
          url,
          {
            client_id: @item_svc.service_integration.backfill_key,
            secret: @item_svc.service_integration.backfill_secret,
            access_token: @plaid_access_token,
            cursor: @cursor,
            count:,
          },
          timeout: Webhookdb::Plaid.sync_timeout,
          logger: @transaction_svc.logger,
        )
      rescue Webhookdb::Http::Error => e
        errtype = e.response.parsed_response["error_type"]
        return [], nil if Webhookdb::Services::PlaidItemV1::STORABLE_ERROR_TYPES.include?(errtype)
        if errtype == "RATE_LIMIT_EXCEEDED"
          backoff = rand(20..59)
          @retry_error = Webhookdb::Async::Job::Retry.new(backoff)
          return [], nil
        end
        raise e
      end

      resp = response.parsed_response
      transactions = resp.fetch("added", []) + resp.fetch("modified", [])
      # We don't bother chunking removed transactions, since their representation is tiny
      # and their update is a separate routine.
      @removed.concat(resp.fetch("removed", []).map { |t| t.fetch("transaction_id") })
      @cursor = response.parsed_response.fetch("next_cursor")
      return transactions, nil unless resp.fetch("has_more")
      # We manage the cursor internally.
      return transactions, :next_page
    end
  end
end
