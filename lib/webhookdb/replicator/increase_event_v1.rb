# frozen_string_literal: true

class Webhookdb::Replicator::IncreaseEventV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::IncreaseV1Mixin

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "increase_event_v1",
      ctor: self,
      feature_roles: [],
      resource_name_singular: "Increase Event",
      dependency_descriptor: Webhookdb::Replicator::IncreaseAppV1.descriptor,
      # Since events are only done through the increase_app_v1,
      # we don't support normal WebhookDB webhooks. Instead,
      # they come in via the app. If we wanted to handle webhooks to the normal
      # /v1/service_integrations/:opaque_id endpoint, rather than /v1/install/increase/webhook,
      # we'd make this 'true' and have to do work like webhook validation.
      # supports_webhooks: false,
      supports_backfill: true,
      api_docs_url: "https://increase.com/documentation/api",
    )
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:increase_id, TEXT, data_key: "id")
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:associated_object_id, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:associated_object_type, TEXT),
      Webhookdb::Replicator::Column.new(:category, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:created_at, TIMESTAMP, index: true),
    ]
  end

  def _timestamp_column_name = :created_at
  def _mixin_object_type = "event"
end
