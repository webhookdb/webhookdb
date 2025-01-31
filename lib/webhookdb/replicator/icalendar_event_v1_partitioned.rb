# frozen_string_literal: true

require "webhookdb/replicator/icalendar_event_v1"
require "webhookdb/replicator/partitionable_mixin"

class Webhookdb::Replicator::IcalendarEventV1Partitioned < Webhookdb::Replicator::IcalendarEventV1
  include Webhookdb::Replicator::PartitionableMixin

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "icalendar_event_v1_partitioned",
      ctor: ->(sint) { self.new(sint) },
      dependency_descriptor: Webhookdb::Replicator::IcalendarCalendarV1.descriptor,
      feature_roles: ["partitioning_beta"],
      resource_name_singular: "iCalendar Event",
      supports_webhooks: true,
      description: "Individual events in an icalendar, using partitioned tables rather than one big table. " \
                   "See icalendar_calendar_v1.",
      api_docs_url: "https://icalendar.org/",
    )
  end

  def _denormalized_columns
    d = super
    d << Webhookdb::Replicator::Column.new(:calendar_external_hash, INTEGER, optional: true)
    return d
  end

  def partition_method = Webhookdb::DBAdapter::Partitioning::HASH
  def partition_column_name = :calendar_external_hash
  def partition_value(resource) = self._str2inthash(resource.fetch("calendar_external_id"))
end
