# frozen_string_literal: true

class Webhookdb::Replicator::PostmarkOutboundMessageEventV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "postmark_outbound_message_event_v1",
      ctor: ->(sint) { Webhookdb::Replicator::PostmarkOutboundMessageEventV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "Postmark Outbound Message Event",
    )
  end

  TIMESTAMP_KEYS = ["ReceivedAt", "DeliveredAt", "BouncedAt", "ChangedAt"].freeze

  LOOKUP_TIMESTAMP = Webhookdb::Replicator::Column::IsomorphicProc.new(
    ruby: lambda do |resource:, **|
      tskey = TIMESTAMP_KEYS.find { |k| resource[k] }
      raise KeyError, "Cannot find valid timestamp key in #{resource}" if tskey.nil?
      resource[tskey]
    end,
  )

  BUILD_EVENT_MD5 = Webhookdb::Replicator::Column::IsomorphicProc.new(
    ruby: lambda do |resource:, **|
      md5 = Digest::MD5.new
      md5.update(resource.fetch("MessageID"))
      md5.update(resource.fetch("RecordType"))
      md5.update(LOOKUP_TIMESTAMP.ruby.call(resource:))
      md5.hexdigest
    end,
  )

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:event_id, UUID, optional: true, defaulter: BUILD_EVENT_MD5)
  end

  def _denormalized_columns
    col = Webhookdb::Replicator::Column
    return [
      col.new(:message_id, TEXT, index: true, data_key: "MessageID"),
      col.new(:timestamp, TIMESTAMP, index: true, optional: true, defaulter: LOOKUP_TIMESTAMP),
      col.new(:record_type, TEXT, index: true, optional: true, data_key: "RecordType"),
      col.new(:tag, TEXT, index: true, optional: true, data_key: "Tag"),
      col.new(:recipient, TEXT, index: true, optional: true, data_key: "Recipient"),
      col.new(:changed_at, TIMESTAMP, index: true, optional: true, data_key: "ChangedAt"),
      col.new(:delivered_at, TIMESTAMP, index: true, optional: true, data_key: "DeliveredAt"),
      col.new(:received_at, TIMESTAMP, index: true, optional: true, data_key: "ReceivedAt"),
      col.new(:bounced_at, TIMESTAMP, index: true, optional: true, data_key: "BouncedAt"),
    ]
  end

  def _timestamp_column_name
    return :timestamp
  end

  def _resource_and_event(request)
    return request.body, nil
  end

  def _update_where_expr
    # Since the primary key is based on the timestamp, we never do updates
    return Sequel[false]
  end

  def _webhook_response(request)
    return Webhookdb::Postmark.webhook_response(request)
  end

  def calculate_create_state_machine
    step = Webhookdb::Replicator::StateMachineStep.new
    if self.service_integration.webhook_secret.blank?
      step.output = %(You are about to set up webhooks for Postmark Outbound Message Events,
like deliveries, clicks, and opens.

1. In the Postmark UI, locate the server and stream (Transactional or Broadcast) you want to record.
2. Click on the 'Webhooks' tab.
3. Use this Webhook URL: #{self.webhook_endpoint}
4. Check the events you want to send.
5. Hit 'Send test' and verify it works. If it does not, double check your settings.
6. Hit 'Save Changes')
      step.set_prompt("Press Enter after Saved Changes succeeds:")
      step.transition_field(self.service_integration, "noop_create")
      self.service_integration.update(webhook_secret: "placeholder")
      return step
    end
    step.output = %(
All set! Events will be synced as they come in.

#{self._query_help_output})
    return step.completed
  end

  def calculate_backfill_state_machine
    step = Webhookdb::Replicator::StateMachineStep.new
    step.output = %(We don't yet support backfilling Postmark Outbound Message Events.

Please email hello@webhookdb.com to let us know if this is something you want!

Run `webhookdb integration reset #{self.service_integration.opaque_id}` to go through webhook setup.

#{self._query_help_output(prefix: "You can query available #{self.resource_name_plural}")})
    step.error_code = "postmark_no_outbound_backfill"
    return step.completed
  end
end
