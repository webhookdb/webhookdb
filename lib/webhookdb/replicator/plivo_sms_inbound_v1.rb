# frozen_string_literal: true

require "webhookdb/plivo"

class Webhookdb::Replicator::PlivoSmsInboundV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "plivo_sms_inbound_v1",
      ctor: ->(sint) { Webhookdb::Replicator::PlivoSmsInboundV1.new(sint) },
      feature_roles: ["beta"],
      resource_name_singular: "Plivo Inbound SMS Message",
      supports_webhooks: true,
    )
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:plivo_message_uuid, TEXT, data_key: "MessageUUID")
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:row_inserted_at, TIMESTAMP, defaulter: :now, optional: true, index: true),
      Webhookdb::Replicator::Column.new(:from_number, TEXT, data_key: "From", index: true),
      Webhookdb::Replicator::Column.new(:to_number, TEXT, data_key: "To", index: true),
    ]
  end

  def _timestamp_column_name
    return :row_inserted_at
  end

  def _update_where_expr
    # These are immutable events, not updates, so never update after inserted.
    return Sequel[false]
  end

  def _webhook_response(request)
    return Webhookdb::Plivo.webhook_response(request, self.service_integration.backfill_secret)
  end

  def _resource_and_event(request)
    body = request.body
    raise Webhookdb::InvalidPrecondition, "body should be form-encoded string" unless body.is_a?(String)
    resource = URI.decode_www_form(body).to_h
    return resource, nil
  end

  INTEGER_KEYS = ["TotalAmount", "TotalRate", "Units"].freeze

  def _resource_to_data(resource, *)
    super
    h = resource.dup
    INTEGER_KEYS.each do |k|
      h[k] = h[k].to_i if h.key?(k)
    end
    return h
  end

  def calculate_webhook_state_machine
    step = Webhookdb::Replicator::StateMachineStep.new
    if self.service_integration.backfill_key.blank?
      step.output = %(You are about to set up an endpoint to receive #{self.resource_name_plural}.
You'll need to give us your Auth ID and Auth Token so we can validate webhooks.
Once that is set up, we'll help you set up your WebhookDB endpoint in Plivo.)
      return step.secret_prompt("Auth ID").backfill_key(self.service_integration)
    end
    if self.service_integration.backfill_secret.blank?
      return step.secret_prompt("Auth Token").backfill_secret(self.service_integration)
    end
    begin
      Webhookdb::Plivo.request(
        :get,
        "/",
        auth_id: self.service_integration.backfill_key,
        auth_token: self.service_integration.backfill_secret,
        timeout: Webhookdb::Plivo.http_timeout,
      )
    rescue Webhookdb::Http::Error => e
      self.service_integration.update(backfill_key: "", backfill_secret: "")
      step.output = %(Those credentials didn't work (Plivo returned an HTTP #{e.status} error).
Let's start over with your Auth ID (it probably begins with an MA or SA).)
      return step.secret_prompt("Auth ID").backfill_key(self.service_integration)
    end
    step.output = %(Perfect, those credentials check out.
You can use this endpoint in your Plivo Application to receive webhooks:

  #{self._webhook_endpoint}

This can be done through the UI, or the API by creating or updating an Application under your Account.

As messages comes in, they'll be upserted into your table.
#{self._query_help_output}

You can also use `webhookdb httpsync` to set up notifications to your own server
when rows are modified.)
    return step.completed
  end
end
