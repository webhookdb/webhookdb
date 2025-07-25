# frozen_string_literal: true

# Implementation of a generic backfill pattern.
class Webhookdb::Backfiller
  # Called for each item.
  def handle_item(_item) = NotImplementedError

  def fetch_backfill_page(pagination_token, last_backfilled:) = raise NotImplementedError

  # Use nil last_backfilled for a full sync, pass it for an incremental.
  # Should be service integration last_backfilled_at, the timestamp of
  # the latest resource, etc.
  def backfill(last_backfilled)
    pagination_token = nil
    loop do
      page, next_pagination_token = self._fetch_backfill_page_with_retry(
        pagination_token, last_backfilled:,
      )
      if page.nil?
        msg = "Fetching a page should return an empty array, not nil. The service response probably is missing a key?"
        raise TypeError, msg
      end
      pagination_token = next_pagination_token
      page.each do |item|
        self.handle_item(item)
      end
      Webhookdb::Async.long_running_job_heartbeat!
      break if pagination_token.blank?
      if Webhookdb.regression_mode?
        Webhookdb.logger.warn("regression_mode_backfill_termination", backfiller: self.to_s, pagination_token:)
        break
      end
    end
    self.flush_pending_inserts if self.respond_to?(:flush_pending_inserts)
  end

  def max_backfill_retry_attempts
    return 3
  end

  def wait_for_retry_attempt(attempt:)
    Webhookdb::Backfiller.do_retry_wait(attempt)
  end

  # Make this easy to mock
  def self.do_retry_wait(seconds) = Kernel.sleep(seconds)

  def _fetch_backfill_page_with_retry(pagination_token, last_backfilled: nil, attempt: 1)
    return self.fetch_backfill_page(pagination_token, last_backfilled:)
  rescue Webhookdb::Http::BaseError => e
    raise e if attempt >= self.max_backfill_retry_attempts
    # Assume we'll never succeed on a 401, so don't bother retrying.
    raise e if e.is_a?(Webhookdb::Http::Error) && e.status == 401
    self.wait_for_retry_attempt(attempt:)
    return self._fetch_backfill_page_with_retry(pagination_token, last_backfilled:, attempt: attempt + 1)
  end

  module Bulk
    def upsert_page_size = raise NotImplementedError("how many items should be upserted at a time")
    def prepare_body(_body) = raise NotImplementedError("add/remove keys from body before upsert")
    def upserting_replicator = raise NotImplementedError("the replicator being upserted")
    def remote_key_column_name = @remote_key_column_name ||= self.upserting_replicator._remote_key_column.name

    def pending_inserts = @pending_inserts ||= {}
    # Should `_update_where_expr` be used or not?
    # Default false, since most bulk upserting is backfill,
    # which should only involve upserting new rows anyway.
    def conditional_upsert? = false

    def dry_run? = false

    # Add the item to pending upserts, and run the page upsert if needed.
    # Return the key, and the item being upserted.
    # @return [Array(String, Hash),Array(nil)]
    def handle_item(body)
      self.prepare_body(body)
      inserting = self.upserting_replicator.upsert_webhook_body(body, upsert: false)
      return nil, nil if inserting.nil?
      k = inserting.fetch(self.remote_key_column_name)
      self.pending_inserts[k] = inserting
      self.flush_pending_inserts if self.pending_inserts.size >= self.upsert_page_size
      return k, inserting
    end

    # Return the conditional update expression.
    # Usually this is:
    # - +nil+ if +conditional_upsert?+ is false.
    # - the +_update_where_expr+ if +conditional_upsert?+ is true.
    # - Can be overridden by a subclass if they need to use a specific conditional update expression
    #   in certain cases (should be rare).
    def update_where_expr = self.conditional_upsert? ? self.upserting_replicator._update_where_expr : nil

    # The upsert 'UPDATE' expression, calculated using the first row of a multi-row upsert.
    # Defaults to +_upsert_update_expr+, but may need to be overridden in rare cases.
    def upsert_update_expr(first_inserting_row) = self.upserting_replicator._upsert_update_expr(first_inserting_row)

    def flush_pending_inserts
      return if self.dry_run?
      return if self.pending_inserts.empty?
      Webhookdb::Async.long_running_job_heartbeat!
      rows_to_insert = self.pending_inserts.values
      update_where_expr = self.update_where_expr
      update_expr = self.upserting_replicator._upsert_update_expr(rows_to_insert.first)
      self.upserting_replicator.admin_dataset(timeout: :fast) do |ds|
        insert_ds = ds.insert_conflict(
          target: self.upserting_replicator._upsert_conflict_target,
          update: update_expr,
          update_where: update_where_expr,
        )
        insert_ds.multi_insert(rows_to_insert)
      end
      self.pending_inserts.clear
    end
  end
end
