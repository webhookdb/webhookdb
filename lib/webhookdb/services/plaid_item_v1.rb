# frozen_string_literal: true

require "webhookdb/plaid"

class Webhookdb::Services::PlaidItemV1 < Webhookdb::Services::Base
  include Appydays::Loggable

  # @return [Webhookdb::Services::Descriptor]
  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "plaid_item_v1",
      ctor: self,
      feature_roles: ["beta"],
      resource_name_singular: "Plaid Item",
    )
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:plaid_id, "text")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:institution_id, "text", index: true),
      Webhookdb::Services::Column.new(:encrypted_access_token, "text"),
      Webhookdb::Services::Column.new(:created_at, "timestamptz", index: true),
      Webhookdb::Services::Column.new(:consent_expiration_time, "timestamptz"),
      Webhookdb::Services::Column.new(:update_type, "text"),
      Webhookdb::Services::Column.new(:error, "jsonb"),
      Webhookdb::Services::Column.new(:available_products, "jsonb"),
      Webhookdb::Services::Column.new(:billed_products, "jsonb"),
      Webhookdb::Services::Column.new(:status, "jsonb"),
    ]
  end

  def upsert_webhook(body:)
    if body.fetch("webhook_type") != "ITEM"
      self.service_integration.dependents.each do |d|
        d.service_instance.upsert_webhook(body:)
      end
      return
    end
    # Webhooks are going to be from plaid, or from the client,
    # so the 'codes' here cover more than just Plaid.
    payload = {
      data: {"item_id" => body.fetch("item_id")}.to_json,
      plaid_id: body.fetch("item_id"),
    }
    case body.fetch("webhook_code")
      when "ERROR", "USER_PERMISSION_REVOKED"
        payload[:error] = body.fetch("error").to_json
      when "PENDING_EXPIRATION"
        payload[:consent_expiration_time] = body.fetch("consent_expiration_time")
      when "CREATED"
        payload.merge!(self._handle_item_create(body.fetch("item_id"), body.fetch("access_token")))
      else
        return nil
    end
    upserted_rows = self.admin_dataset do |ds|
      ds.insert_conflict(
        target: self._remote_key_column.name,
        update: payload,
      ).insert(payload)
    end
    row_changed = upserted_rows.present?
    self._notify_dependents(payload, row_changed)
    return unless row_changed
    self._publish_rowupsert(payload)
  end

  def _handle_item_create(_item_id, access_token)
    encrypted_access_token = Webhookdb::Crypto.encrypt_value(
      Webhookdb::Crypto::Boxed.from_b64(self.service_integration.data_encryption_secret),
      Webhookdb::Crypto::Boxed.from_raw(access_token),
    ).base64

    resp = Webhookdb::Http.get("http://pladtest", logger: self.logger)
    body = resp.parsed_response
    return {
      encrypted_access_token:,
      available_products: body.fetch("item").fetch("available_products").to_json,
      billed_products: body.fetch("item").fetch("billed_products").to_json,
      error: body.fetch("item").fetch("error").to_json,
      institution_id: body.fetch("item").fetch("institution_id"),
      update_type: body.fetch("item").fetch("update_type"),
      consent_expiration_time: body.fetch("item").fetch("consent_expiration_time"),
      status: body.fetch("status").to_json,
    }
  end

  def webhook_response(request)
    return Webhookdb::Plaid.webhook_response(request, self.service_integration.webhook_secret)
  end

  def process_state_change(field, value)
    if field == "api_url"
      value = "https://production.plaid.com" if value.blank? || value.downcase.include?("production")
      value = "https://sandbox.plaid.com" if value.downcase.include?("sandbox")
      value = "https://development.plaid.com" if value.downcase.include?("development")
    end
    super(field, value)
  end

  def calculate_create_state_machine
    step = Webhookdb::Services::StateMachineStep.new
    if self.service_integration.webhook_secret.blank?
      self.service_integration.data_encryption_secret ||= Webhookdb::Crypto.encryption_key.base64
      self.service_integration.save_changes
      step.output = %(You are about to add support for adding Plaid Items (access tokens)
into WebhookDB, which is necessary for other Plaid integrations (such as Transactions) to work.

We have detailed instructions on this process
at https://webhookdb.com/docs/plaid.

The first step is to generate a secret you will use for signing
API requests back to WebhookDB. You can use '#{Webhookdb::Id.rand_enc(16)}'
or generate your own value.
Copy and paste or enter a new value, and press enter.)
      return step.secret_prompt("secret").webhook_secret(self.service_integration)
    end
    if self.service_integration.api_url.blank?
      step.output = %(Great. Now we want to make sure we're sending API requests to the right place.
Plaid uses 3 separate environments:

https://sandbox.plaid.com (Sandbox)
https://development.plaid.com (Development)
https://production.plaid.com (Production)

Leave the prompt blank or use 'production' for production,
or input 'development' or 'sandbox' (or input the URL).
      )
      return step.prompting("API host").api_url(self.service_integration)
    end
    step.output = %(Excellent. We have made a URL available
that you must use for webhooks, both in Plaid and from your backend:

#{self._webhook_endpoint}

At this point, you are ready to follow the detailed instructions
found here: https://webhookdb.com/docs/plaid.

#{self._query_help_output})
    return step.completed
  end

  def calculate_backfill_state_machine
    step = Webhookdb::Services::StateMachineStep.new
    step.output = %(Plaid Items do not support backfilling.
Instead, you must send information about new items to WebhookDB
(we will take care of updates as long as the webhook is set up
when you create tokens).

Your webhook endpoint is:

#{self._webhook_endpoint}

And the secret to use for signing is:

#{self.service_integration.webhook_secret}

Please follow the instructions at https://webhookdb.com/docs/plaid
to sync WebhookDB with Plaid.)
    return step.completed
  end
end
