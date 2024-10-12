# frozen_string_literal: true

# Delete stale rows (like cancelled calendar events) not updated (row_updated_at or whatever column)
# in the window between +stale_at+ to +age_cutoff+.
# This avoids endlessly adding to a table where we expect rows to become stale over time.
class Webhookdb::Replicator::BaseStaleRowDeleter
  def initialize(replicator)
    @replicator = replicator
  end

  # When a row is considered 'stale'.
  # If stale rows are a big problem, this can be shortened to just a few days.
  # @return [ActiveSupport::Duration]
  def stale_at
    raise NotImplementedError
  end

  # Where to stop searching for old rows.
  # This is important to avoid a full table scale when deleting rows,
  # since otherwise it is like 'row_updated_at < 35.days.ago'.
  # Since this routine should run regularly, we should rarely have rows more than 35 or 36 days old,
  # for example.
  # Use +run_initial+ to use a nil cutoff/no limit (a full table scan)
  # which may be necessary when running this feature for a table for the first time.
  # @return [ActiveSupport::Duration]
  def age_cutoff
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
  # The default seems safe, but it's exposed as a parameter if you need to play around with it,
  # and can be done via configuration if needed at some point.
  # @return [Integer]
  def chunk_size = 10_000

  def run(age_cutoff: self.age_cutoff)
    # Delete in chunks, like:
    #   DELETE from "public"."icalendar_event_v1_aaaa"
    #   WHERE pk IN (
    #     SELECT pk FROM "public"."icalendar_event_v1_aaaa"
    #     WHERE row_updated_at < (now() - '35 days'::interval)
    #     LIMIT 10000
    #   )
    age = age_cutoff&.ago..self.stale_at.ago
    @replicator.admin_dataset do |ds|
      chunk_ds = ds.where(self.updated_at_column => age).where(self.stale_condition).select(:pk).limit(self.chunk_size)
      loop do
        # Due to conflicts where a feed is being inserted while the delete is happening,
        # this may raise an error like:
        #   deadlock detected
        #   DETAIL:  Process 18352 waits for ShareLock on transaction 435085606; blocked by process 24191.
        #   Process 24191 waits for ShareLock on transaction 435085589; blocked by process 18352.
        #   HINT:  See server log for query details.
        #   CONTEXT:  while deleting tuple (2119119,3) in relation "icalendar_event_v1_aaaa"
        # Unit testing this is very difficult though, and in practice it is rare,
        # and normal Sidekiq job retries should be sufficient to handle this.
        # So we don't explicitly handle deadlocks, but could if it becomes an issue.
        deleted = ds.where(pk: chunk_ds).delete
        break if deleted != chunk_size
      end
    end
  end

  # Run with +age_cutoff+ as +nil+, which does a full table scan.
  def run_initial = self.run(age_cutoff: nil)
end
