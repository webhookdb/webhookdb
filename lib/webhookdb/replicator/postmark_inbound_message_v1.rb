# frozen_string_literal: true

class Webhookdb::Replicator::PostmarkInboundMessageV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "postmark_inbound_message_v1",
      ctor: ->(sint) { Webhookdb::Replicator::PostmarkInboundMessageV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "Postmark Inbound Message",
    )
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:message_id, TEXT, data_key: "MessageID")
  end

  def _denormalized_columns
    col = Webhookdb::Replicator::Column
    return [
      col.new(:from_email, TEXT, index: true, data_key: ["FromFull", "Email"]),
      col.new(:to_email, TEXT, index: true, data_key: ["ToFull", 0, "Email"]),
      col.new(:subject, TEXT, index: true, data_key: "Subject"),
      col.new(:timestamp, TIMESTAMP, index: true, data_key: "Date"),
      col.new(:tag, TEXT, index: true, data_key: "Tag"),
    ]
  end

  def _timestamp_column_name
    return :timestamp
  end

  def _resource_and_event(request)
    return request.body, nil
  end

  def _update_where_expr
    # These are immutable events, not updates, so never update after inserted.
    return Sequel[false]
  end

  def _webhook_response(request)
    return Webhookdb::Postmark.webhook_response(request)
  end

  def calculate_create_state_machine
    step = Webhookdb::Replicator::StateMachineStep.new
    if self.service_integration.webhook_secret.blank?
      step.output = %(You are about to set up webhooks for Postmark Inbound Messages.
When emails are sent to the email address configured in Postmark,
they will show up in WebhookDB automatically.

1. In the Postmark UI, locate the server and choose the Inbound Stream to record.
2. Go to the 'Settings' tab.
3. Use this Webhook URL: #{self.webhook_endpoint}
5. Hit 'Check' and verify it works. If it does not, double check your settings.
6. Hit 'Save Webhook'.)
      step.set_prompt("Press Enter after Save Webhook succeeds:")
      step.transition_field(self.service_integration, "noop_create")
      self.service_integration.update(webhook_secret: "placeholder")
      return step
    end
    step.output = %(
All set! Inbound Messages will be synced as they come in.

#{self._query_help_output})
    return step.completed
  end

  def calculate_backfill_state_machine
    step = Webhookdb::Replicator::StateMachineStep.new
    step.output = %(We don't yet support backfilling Postmark Inbound Messages.
Please email hello@webhookdb.com to let us know if this is something you want!

Run `webhookdb integration reset #{self.service_integration.opaque_id}` to go through webhook setup.

#{self._query_help_output(prefix: "You can query available #{self.resource_name_plural}")})
    step.error_code = "postmark_no_inbound_backfill"
    return step.completed
  end
end
