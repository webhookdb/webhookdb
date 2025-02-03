# frozen_string_literal: true

# Mixin for replicators that support partitioning.
# Partitioning is currently in beta,
# with the following limitations/context:
#
# - They cannot be created from the CLI.
#   Because the partitions must be created during the CREATE TABLE call,
#   the partition_value must be set immediately on creation,
#   or CREATE TABLE must be deferred.
# - CLI support would also require making sure this field isn't edited.
#   This is an annoying change, so we're putting it off for now.
# - Instead, partitioned replicators must be created in the console.
# - The number of HASH partitions cannot be changed;
#   there is no good way to handle this in Postgres so we don't bother here.
# - RANGE partitions are not supported.
#   We need to support creating the partition when the INSERT fails.
#   But creating the partitioned table definition itself does work/has a shared behavior at least.
# - Existing replicators cannot be converted to partitioned.
#   This is theoretically possible, but it seems easier to just start over
#   with a new replicator.
# - Instead:
#   - If this is a 'child' replicator, then create a new parent and this child,
#     then copy over the parent data, either directly (for icalendar)
#     or using HTTP requests (like with Plaid or Google) where more logic is required.
#   - Otherwise, it'll depend on the replicator.
#   - Then to switch clients using the old replicator, to the new replicator, you can:
#     - Then turn off all workers.
#     - Rename the new table to the old, and old table to the new.
#     - Update the service integrations, so the old one points to the new table name and opaque id,
#       and the new one points to the old table name and opaque id.
#
module Webhookdb::Replicator::PartitionableMixin
  # The partition method, like Webhookdb::DBAdapter::Partitioning::HASH
  def partition_method = raise NotImplementedError
  # The partition column name.
  # Must be present in +_denormalized_columns+.
  # @return [Symbol]
  def partition_column_name = raise NotImplementedError
  # The value for the denormalized column. For HASH partitioning this would be an integer,
  # for RANGE partitioning this could be a timestamp, etc.
  # Takes the resource and returns the value.
  def partition_value(_resource) = raise NotImplementedError

  def partition? = true

  def partitioning
    return Webhookdb::DBAdapter::Partitioning.new(by: self.partition_method, column: self.partition_column_name)
  end

  def _prepare_for_insert(resource, event, request, enrichment)
    h = super
    h[self.partition_column_name] = self.partition_value(resource)
    return h
  end

  def _upsert_conflict_target
    return [self.partition_column_name, self._remote_key_column.name]
  end

  # Convert the given string into a stable MD5-derived hash
  # that can be stored in a (signed, 4 bit) INTEGER column.
  def _str2inthash(s)
    # MD5 is 128 bits/16 bytes/32 hex chars (2 chars per byte).
    # Integers are 32 bits/4 bytes/8 hex chars.
    # Grab the first 8 chars and convert it to an integer.
    unsigned_md5int = Digest::MD5.hexdigest(s)[..8].to_i(16)
    # Then AND it with a 32 bit bitmask to make sure it fits in 32 bits
    # (though I'm not entirely sure why the above doesn't result in 32 bits always).
    unsigned_int32 = unsigned_md5int & 0xFFFFFFFF
    # Convert it from unsigned (0 to 4.2B) to signed (-2.1B to 2.1B) by subtracting 2.1B
    # (the max 2 byte integer), as opposed to a 4 byte integer which we're dealing with here.
    signed_md5int = unsigned_int32 - MAX_16BIT_INT
    return signed_md5int
  end

  MAX_16BIT_INT = 2**31

  # Return the partitions belonging to the table.
  # @return [Array<Webhookdb::DBAdapter::Partition>]
  def existing_partitions
    # SELECT inhrelid::regclass AS child
    # FROM   pg_catalog.pg_inherits
    # WHERE  inhparent = 'my_schema.foo'::regclass;
    parent = self.schema_and_table_symbols.map(&:to_s).join(".")
    partnames = self.service_integration.organization.admin_connection do |db|
      db[Sequel[:pg_catalog][:pg_inherits]].
        where(inhparent: Sequel[parent].cast(:regclass)).
        select_map(Sequel[:inhrelid].cast(:regclass))
    end
    parent_table = self.dbadapter_table
    result = partnames.map do |part|
      suffix = self.partition_suffix(part)
      Webhookdb::DBAdapter::Partition.new(parent_table:, partition_name: part.to_sym, suffix:)
    end
    return result
  end

  def partition_suffix(partname)
    return partname[/_[a-zA-Z\d]+$/].to_sym
  end

  def partition_align_name
    tblname = self.service_integration.table_name
    partitions = self.existing_partitions
    self.service_integration.organization.admin_connection do |db|
      db.transaction do
        partitions.each do |partition|
          next if partition.partition_name.to_s.start_with?(tblname)
          schema = partition.parent_table.schema.name
          new_partname = "#{tblname}#{partition.suffix}"
          db << "ALTER TABLE #{schema}.#{partition.partition_name} RENAME TO #{new_partname}"
        end
      end
    end
  end
end
