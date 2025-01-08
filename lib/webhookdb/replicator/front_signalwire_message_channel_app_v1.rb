# frozen_string_literal: true

require "jwt"

require "webhookdb/messages/error_signalwire_send_sms"
require "webhookdb/replicator/front_v1_mixin"
require "webhookdb/jobs/front_signalwire_message_channel_sync_inbound"

# Front has a system of 'channels' but it is a challenge to use.
# This replicator leverages WebhookDB (and our existing Front app)
# to integrate Front and SignalWire messages,
# using a sort of two-way sync that implements the necessary Front channel contrWcts.
#
# Note: In the future, we can abstract this to support other channels, with minimal changes.
#
# We have the following concepts to keep in mind:
#
# - The front_message_v1 replicator stores ALL messages in Front (inbound and outbound).
# - The signalwire_message_v1 replicator stores ALL messages in SignalWire (inbound and outbound).
# - For two-way sync, we care that Outbound Front messages are turned into Outbound SignalWire messages,
#   and Inbound SignalWire messages are turned into Inbound Front messages.
# - This means that, for the purpose of a two-way sync, this replicator can 'enqueue' deliveries by storing
#   a row with *either* a Front message id (query Front for all outbound messages),
#   *or* SignalWire message id (query signalwire for all inbound messages). When a row has *both* ids,
#   it means it has been "delivered", so to speak.
# - We can ignore inbound Front messages and outbound SignalWire messages
#   (stored in their respective replicators), since those are created by this replicator.
#
# This means that, rather than having to manage state between two event-based systems,
# we can *converge* to a correct state based on a given state.
# This is much easier (possible?) to reason about and test,
# and makes it possible to reuse code,
#
# The order of operations is:
# - The channel description instructs the user to go to /v1/install/front_signalwire/setup.
# - This loads a terminal, showing instructions for how to set up
#   (enabling the WebhookDB Front app, setting up SignalWire).
# - The state machine also asks for the phone number to use to send messages.
#   - The phone number used to send messages is stored in the api_url.
# - The state machine prints out the API token to use in Front.
#   - The api token is stored in the 'webhookdb_api_key' field, which is searchable.
# - The user is directed to Front, to install the WebhookDB SignalWire channel.
# - The user inputs their API token and connects the channel.
# - Front makes an 'authorization' request to /v1/install/front_signalwire/authorization.
#   - This uses the API key to find the right front_signalwire_message_channel_app_v1 integration
#     via the webhookdb_api_key field.
#   - This stores the channel_id on the integration as the api_url.
# - Front makes 'message' requests to /v1/install/front_signalwire/message/<opaque id>.
#   - This upserts a DB row into the front_message_v1 replicator.
#   - It also enqueues a backfill of this replicator.
# - Front can make a 'delete' request to /v1/install/front_signalwire/message/<opaque id>.
#   - This deletes deletes this service integration.
# - Because this replicator is a dependent of signalwire_message_v1 (see explanation below),
#   whenever a signalwire row is updated, this replicator will be triggered and enqueue a backfill.
# - When this replicator backfills, it will:
#   - Look for inbound SMS, and upsert a row into this replication table.
#   - Look for outbound Front messages, and upsert a row into this replication table.
#   - Find replication table rows without a signalwire id, and send an SMS.
#   - Find replication table rows without a Front message id, and create a Front message
#     using https://dev.frontapp.com/reference/sync-inbound-message
#
class Webhookdb::Replicator::FrontSignalwireMessageChannelAppV1 < Webhookdb::Replicator::Base
  include Webhookdb::DBAdapter::ColumnTypes

  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "front_signalwire_message_channel_app_v1",
      ctor: self,
      feature_roles: [],
      resource_name_singular: "Front/SignalWire Message",
      dependency_descriptor: Webhookdb::Replicator::SignalwireMessageV1.descriptor,
      supports_webhooks: true,
      supports_backfill: true,
      api_docs_url: "https://dev.frontapp.com/docs/getting-started-with-partner-channels",
    )
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:external_id, TEXT)
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:signalwire_sid, TEXT, optional: true, index: true),
      Webhookdb::Replicator::Column.new(:front_message_id, TEXT, optional: true, index: true),
      Webhookdb::Replicator::Column.new(:external_conversation_id, TEXT, optional: true, index: true),
      Webhookdb::Replicator::Column.new(:row_updated_at, TIMESTAMP, defaulter: :now, optional: true, index: true),
      Webhookdb::Replicator::Column.new(:direction, TEXT),
      Webhookdb::Replicator::Column.new(:body, TEXT),
      Webhookdb::Replicator::Column.new(:sender, TEXT),
      Webhookdb::Replicator::Column.new(:recipient, TEXT),
    ]
  end

  def _timestamp_column_name
    return :row_updated_at
  end

  def _update_where_expr
    return (self.qualified_table_sequel_identifier[:signalwire_sid] =~ nil) |
        (self.qualified_table_sequel_identifier[:front_message_id] =~ nil)
  end

  def format_phone(s) = Webhookdb::PhoneNumber.format_e164(s)
  def support_phone = self.format_phone(self.service_integration.api_url)

  def calculate_webhook_state_machine
    if (step = self.calculate_dependency_state_machine_step(dependency_help: ""))
      return step
    end
    step = Webhookdb::Replicator::StateMachineStep.new
    if self.service_integration.api_url.blank?
      step.output = %(This Front Channel will be linked to a specific number in SignalWire.
Choose the phone number to connect to Front.)
      return step.prompting("Phone number").api_url(self.service_integration)
    end
    self.service_integration.webhookdb_api_key ||= self.service_integration.new_api_key
    self.service_integration.save_changes
    step.output = %(Almost there! You can now finish installing the SignalWire Channel in Front.

1. In Front, go to Settings -> Company -> Channels (in the left nav), Connect a Channel,
   and choose the 'WebhookDB/SignalWire' channel.
2. In the 'Token' field, enter this API Key: #{self.service_integration.webhookdb_api_key}

If you need to find this key, you can run `webhookdb integrations info front_signalwire_message_channel_app_v1`.

All of this information can be found in the WebhookDB docs, at https://docs.webhookdb.com/guides/front-channel-signalwire/)
    return step.completed
  end

  def calculate_backfill_state_machine
    # The backfills here are not normal backfills, requested by the customer.
    # They are procedurally enqueued when we upsert data.
    # So just reuse the webhook state machine.
    return self.calculate_webhook_state_machine
  end

  def clear_webhook_information
    # We say we support backfill, so this won't get cleared normally.
    self._clear_backfill_information
    super
  end

  def process_webhooks_synchronously? = true

  def synchronous_processing_response_body(upserted:, request:)
    case request.body["type"]
      when "authorization"
        self.front_channel_id = request.body.fetch("payload").fetch("channel_id")
        self.service_integration.save_changes
        return {type: "success", webhook_url: "#{Webhookdb.api_url}/v1/install/front_signalwire/channel"}.to_json
      when "delete"
        self.service_integration.destroy_self_and_all_dependents
        return "{}"
      when "message", "message_autoreply"
        return {
          type: "success",
          external_id: upserted.map { |r| r.fetch(:external_id) }.join(","),
          external_conversation_id: upserted.map { |r| r.fetch(:external_conversation_id) }.join(","),
        }.to_json
      else
        return "{}"
    end
  end

  def front_channel_id = self.service_integration.backfill_key

  def front_channel_id=(c)
    self.service_integration.backfill_key = c
  end

  def _webhook_response(request)
    return Webhookdb::Front.webhook_response(request, Webhookdb::Front.signalwire_channel_app_secret)
  end

  def _resource_and_event(request)
    type = request.body["type"]
    is_signalwire = type.nil?
    return request.body, nil if is_signalwire

    # This ends up being called for 'authorization' and 'delete' messages too.
    # Those are handled in the webhook response body.
    is_message_type = ["message", "message_autoreply"].include?(type)
    return nil, nil unless is_message_type

    resource = request.body.dup
    payload = resource.fetch("payload")
    mid = if type == "message"
            payload.fetch("id")
      else
        replied_to_id = payload["_links"]["related"]["message_replied_to"].split("/").last
        "#{replied_to_id}_autoreply"
    end
    resource["front_message_id"] = mid
    resource["direction"] = "outbound"
    resource["body"] = payload.fetch("text")
    resource["sender"] = self.support_phone
    resources = self._front_recipient_phones(payload).map do |recipient|
      r = resource.dup
      r["recipient"] = recipient
      # The same message can go to multiple recipients, but we want to treat them as separate conversations.
      # That is, we CANNOT use signalwire/front to do 'group chats' since we don't want to
      # allow one user to send a message that is sent to other users (would be a spam vector).
      r["external_id"] = "#{mid}-#{recipient}"
      # Thread this message into the recipient's specific conversation, unlike email.
      r["external_conversation_id"] = recipient
      r
    end
    return resources, nil
  end

  def _front_recipient_phones(payload)
    recipients = payload["recipients"].select { |r| r.fetch("role") == "to" }
    raise Webhookdb::InvariantViolation, "no recipient found in #{payload}" if recipients.empty?
    return recipients.map { |r| self.format_phone(r.fetch("handle")) }
  end

  def on_dependency_webhook_upsert(_sw_replicator, sw_payload, changed:)
    return unless changed

    # If the signalwire message is failed, update the Front convo with a notification that the send failed
    failed_notifier_cutoff = Time.now - 4.days
    signalwire_send_failed = sw_payload.fetch(:date_updated) > failed_notifier_cutoff &&
      ["failed", "undelivered"].include?(sw_payload.fetch(:status)) &&
      sw_payload.fetch(:from) == self.support_phone
    self.alert_async_failed_signalwire_send(sw_payload) if signalwire_send_failed

    # If a message has come in from a user, insert a row so it'll be imported into Front
    signalwire_payload_inbound_to_support = sw_payload.fetch(:direction) == "inbound" &&
      sw_payload.fetch(:to) == self.support_phone
    return unless signalwire_payload_inbound_to_support

    body = JSON.parse(sw_payload.fetch(:data))
    body.merge!(
      "external_id" => sw_payload.fetch(:signalwire_id),
      "signalwire_sid" => sw_payload.fetch(:signalwire_id),
      "direction" => "inbound",
      "sender" => sw_payload.fetch(:from),
      "recipient" => self.support_phone,
      "external_conversation_id" => sw_payload.fetch(:from),
    )
    self.upsert_webhook_body(body)
  end

  def _notify_dependents(inserting, changed)
    super
    return unless changed
    Webhookdb::BackfillJob.create_recursive(service_integration: self.service_integration, incremental: true).enqueue
  end

  # Send alerts for any undelivered or failed messages.
  # The (outbound) message is already created in Front, but if the Signalwire message fails to send,
  # we need to import a new message into Front as a reply explaining why the message failed to send.
  def alert_async_failed_signalwire_send(sw_row)
    idempotency_key = "fsmca-swfail-#{sw_row.fetch(:signalwire_id)}"
    idempotency = Webhookdb::Idempotency.once_ever.stored.using_seperate_connection.under_key(idempotency_key)
    idempotency.execute do
      # The 'sender' of this message is who the failed message is sent **to**
      sender = sw_row.fetch(:to)
      data = JSON.parse(sw_row.fetch(:data))
      external_id = sw_row.fetch(:signalwire_id)
      external_conversation_id = sender
      trunc_body = data.fetch("body", "")[..25]
      body = "SMS failed to send. Error (#{data['error_code'] || '-'}): #{data['error_message'] || '-'}\n#{trunc_body}"
      kwargs = {sender:, delivered_at: Time.now.to_i, body:, external_id:, external_conversation_id:}
      # The call to Front MUST be done in a job, since if it fails, we would not be able to retry.
      # The code is called after the signalwire payload is upserted and changes;
      # but if this fails, the row won't change again in the future,
      # so this code wouldn't be called again.
      # This is a general problem and should probably have a general solution,
      # but because of the external call, it is important to guard against it.
      Webhookdb::Jobs::FrontSignalwireMessageChannelSyncInbound.perform_async(
        self.service_integration.id, kwargs.as_json,
      )
    end
  end

  def sync_front_inbound_message(sender:, delivered_at:, body:, external_id:, external_conversation_id:)
    body = {
      sender: {handle: sender},
      body:,
      delivered_at:,
      metadata: {external_id:, external_conversation_id:},
    }
    token = JWT.encode(
      {
        iss: Webhookdb::Front.signalwire_channel_app_id,
        jti: Webhookdb::Front.channel_jwt_jti,
        sub: self.front_channel_id,
        exp: 10.seconds.from_now.to_i,
      },
      Webhookdb::Front.signalwire_channel_app_secret,
    )
    resp = Webhookdb::Http.post(
      "https://api2.frontapp.com/channels/#{self.front_channel_id}/inbound_messages",
      body,
      headers: {"Authorization" => "Bearer #{token}"},
      timeout: Webhookdb::Front.http_timeout,
      logger: self.logger,
    )
    return resp.parsed_response
  end

  def _backfillers = [Backfiller.new(self)]

  class Backfiller < Webhookdb::Backfiller
    def initialize(replicator)
      super()
      @replicator = replicator
      @signalwire_sint = replicator.service_integration.depends_on
    end

    def handle_item(db_row)
      front_id = db_row.fetch(:front_message_id)
      sw_id = db_row.fetch(:signalwire_sid)
      # This is sort of gross- we get the db row here, and need to re-update it with certain fields
      # as a result of the signalwire or front sync. To do that, we need to run the upsert on 'data',
      # but what's in 'data' is incomplete. So we use the db row to form a more fully complete 'data'.
      upserting_data = db_row.dup
      # Remove the columns that don't belong in 'data'
      upserting_data.delete(:pk)
      upserting_data.delete(:row_updated_at)
      # Splat the 'data' column into the row so it all gets put back into 'data'
      upserting_data.merge!(**upserting_data.delete(:data))
      if (front_id && sw_id) || (!front_id && !sw_id)
        msg = "row should have a front id OR signalwire id, should not have been inserted, or selected: #{db_row}"
        raise Webhookdb::InvariantViolation, msg
      end
      sender = @replicator.format_phone(db_row.fetch(:sender))
      recipient = @replicator.format_phone(db_row.fetch(:recipient))
      body = db_row.fetch(:body)
      idempotency_key = "fsmca-fims-#{db_row.fetch(:external_id)}"
      idempotency = Webhookdb::Idempotency.once_ever.stored.using_seperate_connection.under_key(idempotency_key)
      if front_id.nil?
        texted_at = Time.parse(db_row.fetch(:data).fetch("date_created"))
        if texted_at < Webhookdb::Front.channel_sync_refreshness_cutoff.seconds.ago
          # Do not sync old rows, just mark them synced
          upserting_data[:front_message_id] = "skipped_due_to_age"
        else
          # sync the message into Front
          front_response_body = idempotency.execute do
            self._sync_front_inbound(sender:, texted_at:, db_row:, body:)
          end
          upserting_data[:front_message_id] = front_response_body.fetch("message_uid")
        end
      else
        messaged_at = Time.at(db_row.fetch(:data).fetch("payload").fetch("created_at"))
        if messaged_at < Webhookdb::Front.channel_sync_refreshness_cutoff.seconds.ago
          # Do not sync old rows, just mark them synced
          upserting_data[:signalwire_sid] = "skipped_due_to_age"
        else
          # send the SMS via signalwire
          signalwire_resp = _send_sms(
            idempotency,
            from: sender,
            to: recipient,
            body:,
          )
          upserting_data[:signalwire_sid] = signalwire_resp.fetch("sid") if signalwire_resp
        end
      end
      @replicator.upsert_webhook_body(upserting_data.deep_stringify_keys)
    end

    def _send_sms(idempotency, from:, to:, body:)
      return idempotency.execute do
        Webhookdb::Signalwire.send_sms(
          from:,
          to:,
          body:,
          space_url: @signalwire_sint.api_url,
          project_id: @signalwire_sint.backfill_key,
          api_key: @signalwire_sint.backfill_secret,
          logger: @replicator.logger,
        )
      end
    rescue Webhookdb::Http::Error => e
      response_body = e.body
      response_status = e.status
      request_url = e.uri.to_s
      @replicator.logger.warn("signalwire_send_sms_error",
                              response_body:, response_status:, request_url:, sms_from: from, sms_to: to,)
      code = begin
        # If this fails for whatever reason, or there is no 'code', re-raise the original error
        e.response.parsed_response["code"]
      rescue StandardError
        nil
      end
      # All known codes are for the integrator, not on the webhookdb code side.
      # https://developer.signalwire.com/guides/how-to-troubleshoot-common-messaging-issues
      raise e if code.nil?

      # Error handling note as of Jan 2025:
      # We are choosing to handle synchronous 'send sms' errors through the org alert system,
      # which will tell developers (not support agents) about the failure.
      # This is because, if this send fails, it will be retried later.
      # For example, if we sent a bulk message to 1000 customers,
      # and Signalwire was down and failed 500 sends, we would just retry the 500 sends.
      # We do NOT want to update the 500 failed conversations, and force support agents
      # to deal with the fallout of retrying a send only to those 500 people.
      message = Webhookdb::Messages::ErrorSignalwireSendSms.new(
        @replicator.service_integration,
        response_status:,
        response_body:,
        request_url:,
        request_method: "POST",
      )
      @replicator.service_integration.organization.alerting.dispatch_alert(message)
      return nil
    end

    def _sync_front_inbound(sender:, texted_at:, db_row:, body:)
      body ||= "<no body>"
      return @replicator.sync_front_inbound_message(
        sender:,
        delivered_at: texted_at.to_i,
        body:,
        external_id: db_row.fetch(:external_id),
        external_conversation_id: db_row.fetch(:external_conversation_id),
      )
    end

    def fetch_backfill_page(*)
      rows = @replicator.admin_dataset do |ds|
        ds.where(Sequel[signalwire_sid: nil] | Sequel[front_message_id: nil]).all
      end
      return rows, nil
    end
  end
end
