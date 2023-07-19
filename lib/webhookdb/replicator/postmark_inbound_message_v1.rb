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
      supports_webhooks: true,
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

  def _prepare_for_insert(*)
    h = super
    ts_str = h[:timestamp]
    # We get some weird time formats, like 'Wed, 05 Jul 2023 22:27:31 +0000 (UTC)'.
    # Ruby can parse these, but PG cannot, so sanitize the ' (UTC)' out of here.
    # Depending on what other random stuff we see, we can make this more general later.
    h[:timestamp] = ts_str.gsub(/ \(UTC\)$/, "")
    return h
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

  def calculate_webhook_state_machine
    step = Webhookdb::Replicator::StateMachineStep.new
    if self.service_integration.webhook_secret.blank?
      step.output = %(You are about to set up webhooks for Postmark Inbound Messages.
When emails are sent to the email address configured in Postmark,
they will show up in WebhookDB automatically.

1. Go to https://account.postmarkapp.com/servers
2. Choose the server you want to replicator.
3. Choose the Inbound Stream to replicate.
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

  def backfill_not_supported_message
    return %(We don't yet support backfilling Postmark Inbound Messages.
Please email hello@webhookdb.com to let us know if this is something you want!

Run `webhookdb integration reset #{self.service_integration.opaque_id}` to go through webhook setup.)
  end
end
