# frozen_string_literal: true

# Delete stale rows (like cancelled calendar events) not updated (row_updated_at or whatever column)
# in the window between +stale_at+ back to +lookback_window+.
# This avoids endlessly adding to a table where we expect rows to become stale over time.
class Webhookdb::Replicator::BaseStaleRowDeleter
  # @return [Webhookdb::Replicator::Base]
  attr_reader :replicator

  def initialize(replicator)
    @replicator = replicator
  end

  # When a row is considered 'stale'.
  # For example, a value of +35.days+ would treat any row older than 35 days as stale.
  # @return [ActiveSupport::Duration]
  def stale_at
    raise NotImplementedError
  end

  # How far from +stale_at+ to "look back" for stale rows.
  # We cannot just use "row_updated_at < stale_at" since this would scan ALL the rows
  # every time we delete rows. Instead, we only want to scale rows where
  # "row_updated_at < stale_at AND row_updated_at > (stale_at - lookback_window)".
  # For example, a +stale_at+ of 20 days and a +lookback_window+ of 7 days
  # would look to delete rows 20 to 27 days old.
  #
  # If the stale row deleter is run daily, a good lookback window would be 2-3 days,
  # since as long as the job is running we shouldn't find rows that aren't cleaned up.
  #
  # Use +run_initial+ to do a full table scan,
  # which may be necessary when running this feature for a table for the first time.
  # @return [ActiveSupport::Duration]
  def lookback_window
    raise NotImplementedError
  end

  # Name of the column, like +:row_updated_at+.
  # @return [Symbol]
  def updated_at_column
    raise NotImplementedError
  end

  # Other additional 'stale' conditions, like {status: 'cancelled'}
  # @return [Hash]
  def stale_condition
    raise NotImplementedError
  end

  # The row delete is done in chunks to avoid long locks.
  # The default seems safe, but it's exposed if you need to play around with it,
  # and can be done via configuration if needed at some point.
  # @return [Integer]
  def chunk_size = 10_000

  # How small should the incremental lookback window be? See +run+ for details.
  # A size of 1 hour, and a lookback window of 2 days, would yield at least 48 delete queries.
  def incremental_lookback_size = 1.hour

  # Run the deleter.
  # @param lookback_window [nil,ActiveSupport::Duration] The lookback window
  #   (how many days before +stale_cutoff+ to look for rows). Use +nil+ to look for all rows.
  def run(lookback_window: self.lookback_window)
    # The algorithm to delete stale rows is complex for a couple of reasons.
    # The native solution is "delete rows where updated_at > (stale_at - lookback_window) AND updated_at < stale_at"
    # However, this would cause a single massive query over the entire candidate row space,
    # which has problems:
    # - The query can be very slow
    # - Deadlocks can happen due to the slow query.
    # - If the query is interrupted (due to a worker restart), all progress is lost.
    # - Scanning the large 'updated at timestamp' index can cause the database to do a sequential scan.
    #
    # Instead, we need to do issue a series of fast queries over small 'updated at' windows:
    #
    # - Break the lookback period into hour-long windows.
    #   If the lookback_window is 2 days, this would issue 48 queries.
    #   But each one would be very fast, since the column is indexed.
    # - For each small window, delete in chunks, like:
    #      DELETE from "public"."icalendar_event_v1_aaaa"
    #      WHERE pk IN (
    #        SELECT pk FROM "public"."icalendar_event_v1_aaaa"
    #        WHERE row_updated_at >= (hour start)
    #        AND row_updated_at < (hour end)
    #        LIMIT (chunk size)
    #      )
    # - Issue each DELETE within a transaction with seqscan disabled.
    #   This is crude, but we know for our usage case that we never want a seqscan.
    # - Using the chunked delete with the hour-long (small-sized) windows
    #   is important. Because each chunk requires scanning potentially the entire indexed row space,
    #   it would take longer and longer to find 10k rows to fill the chunk.
    #   This is, for example, the same performance problem that OFFSET/LIMIT pagination
    #   has at later pages (but not earlier pages).
    self.replicator.admin_dataset do |ds|
      stale_window_late = Time.now - self.stale_at
      stale_window_early = lookback_window.nil? ? ds.min(self.updated_at_column) : stale_window_late - lookback_window
      # If we are querying the whole table (no lookback window), and have no rows,
      # there's nothing to clean up.
      break if stale_window_early.nil?

      # We must disable vacuuming for this sort of cleanup.
      # Otherwise, it will take a LONG time since we use a series of short deletes.
      self.set_autovacuum(ds.db, false)
      if self.replicator.partition?
        # If the replicator is partitioned, we need to delete stale rows on partition separately.
        # We DELETE with a LIMIT in chunks, but when we run this on the main table, it'll run the query
        # on every partition BEFORE applying the limit. You'll see this manifest with speed,
        # but also the planner using a sequential scan for the delete, rather than hitting an index.
        # Instead, DELETE from each partition in chunks, which will use the indices, and apply the limit properly.
        self.replicator.existing_partitions(ds.db).each do |p|
          pdb = ds.db[self.replicator.qualified_table_sequel_identifier(table: p.partition_name)]
          self._run_delete(pdb, stale_window_early:, stale_window_late:)
        end
      else
        self._run_delete(ds, stale_window_early:, stale_window_late:)
      end
    end
  ensure
    # Open a new connection in case the previous one is trashed for whatever reason.
    self.replicator.admin_dataset do |ds|
      self.set_autovacuum(ds.db, true)
    end
  end

  def _run_delete(ds, stale_window_early:, stale_window_late:)
    base_ds = ds.where(self.stale_condition).limit(self.chunk_size).select(:pk)
    window_start = stale_window_early
    until window_start >= stale_window_late
      window_end = window_start + self.incremental_lookback_size
      inner_ds = base_ds.where(self.updated_at_column => window_start..window_end)
      loop do
        # Due to conflicts where a feed is being inserted while the delete is happening,
        # this may raise an error like:
        #   deadlock detected
        #   DETAIL:  Process 18352 waits for ShareLock on transaction 435085606; blocked by process 24191.
        #   Process 24191 waits for ShareLock on transaction 435085589; blocked by process 18352.
        #   HINT:  See server log for query details.
        #   CONTEXT:  while deleting tuple (2119119,3) in relation "icalendar_event_v1_aaaa"
        # So we don't explicitly handle deadlocks, but could if it becomes an issue.
        delete_ds = ds.where(pk: inner_ds)
        # Disable seqscan for the delete. We can end up with seqscans if the planner decides
        # it's a better choice given the 'updated at' index, but for our purposes we know
        # we never want to use it (the impact is negligible on small tables,
        # and catastrophic on large tables).
        sql_lines = [
          "BEGIN",
          "SET LOCAL enable_seqscan='off'",
          delete_ds.delete_sql,
          "COMMIT",
        ]
        deleted = ds.db << sql_lines.join(";\n")
        break if deleted != self.chunk_size
      end
      window_start = window_end
    end
  end

  def set_autovacuum(db, on)
    return if self.replicator.partition?
    arg = on ? "on" : "off"
    db << "ALTER TABLE #{self.replicator.schema_and_table_symbols.join('.')} SET (autovacuum_enabled='#{arg}')"
  end

  # Run with +lookback_window+ as +nil+, which does a full table scan.
  def run_initial = self.run(lookback_window: nil)
end
