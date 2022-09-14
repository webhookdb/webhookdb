# frozen_string_literal: true

require "webhookdb/plaid"

class Webhookdb::Services::PlaidItemV1 < Webhookdb::Services::Base
  include Appydays::Loggable

  # If the Plaid request fails for one of these errors,
  # rather than error, we store the response as in the 'error' field
  # since the issue is not on our end.
  STORABLE_ERROR_TYPES = [
    "INVALID_INPUT",
    "ITEM_ERROR",
  ].to_set

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
    return Webhookdb::Services::Column.new(:plaid_id, TEXT, data_key: "item_id")
  end

  def _denormalized_columns
    # These are only added during the initial create call,
    # so are optional and should never be set to nil if they are not present.
    on_create_only = {skip_nil: true, from_enrichment: true, optional: true}

    # Error and consent expiration seem to be mutually exclusive.
    # So when one is set, we want to set the other to nil.
    mutually_exclusive = {from_enrichment: true, optional: true}
    return [
      Webhookdb::Services::Column.new(:row_created_at, TIMESTAMP, index: true, optional: true, defaulter: :now),
      Webhookdb::Services::Column.new(:row_updated_at, TIMESTAMP, index: true, optional: true, defaulter: :now),
      Webhookdb::Services::Column.new(:transaction_sync_next_cursor, TEXT, optional: true, skip_nil: true),

      # on_create_only
      Webhookdb::Services::Column.new(:available_products, OBJECT, **on_create_only),
      Webhookdb::Services::Column.new(:billed_products, OBJECT, **on_create_only),
      Webhookdb::Services::Column.new(:encrypted_access_token, TEXT, **on_create_only),
      Webhookdb::Services::Column.new(:institution_id, TEXT, index: true, **on_create_only),
      Webhookdb::Services::Column.new(:status, OBJECT, **on_create_only),
      Webhookdb::Services::Column.new(:update_type, TEXT, **on_create_only),

      # mutually_exclusive
      Webhookdb::Services::Column.new(:consent_expiration_time, TIMESTAMP, index: true, **mutually_exclusive),
      Webhookdb::Services::Column.new(:error, OBJECT, **mutually_exclusive),
    ]
  end

  def _update_where_expr
    # This is not very applicable here, because the webhooks are basically partial updates,
    # rather than full resource updates. Sort of? Consent and error columns will still conflict.
    return Sequel[true]
  end

  def _upsert_update_expr(inserting, **_kwargs)
    # Only set created_at if it's not set so the initial insert isn't modified.
    return self._coalesce_excluded_on_update(inserting, [:row_created_at])
  end

  def _timestamp_column_name
    return :row_updated_at
  end

  def upsert_has_deps?
    return true
  end

  def _resource_and_event(request)
    body = request.body
    # Remember Plaid webhooks are very different from what is normally meant by 'webhook',
    # more like 'here is information about a thing that happened to an item with this id'.
    # So 'resource' for Plaid Items is ONLY {'item_id' => <id>}.
    # The 'event' is whatever the API sends us (which always includes an item id).
    return {"item_id" => body.fetch("item_id")}, body
  end

  def upsert_webhook(request)
    if request.body.fetch("webhook_type") != "ITEM"
      self.service_integration.dependents.each do |d|
        d.service_instance.upsert_webhook(request)
      end
      return
    end
    begin
      super
    rescue Webhookdb::RegressionModeSkip
      nil
    end
  end

  def _fetch_enrichment(_resource, event, _request)
    # Ignore 'resource' which is just {item_id: ''}, the 'event' contains the real webhook.
    case event.fetch("webhook_code")
      when "ERROR", "USER_PERMISSION_REVOKED"
        return {"error" => self._nil_or_json(event.fetch("error"))}
      when "PENDING_EXPIRATION"
        return {"consent_expiration_time" => event.fetch("consent_expiration_time")}
      when "CREATED"
        return self._handle_item_create(event.fetch("access_token"))
      when "UPDATED"
        return self._handle_item_refresh(event.fetch("item_id"))
      else
        return {}
    end
  end

  def _handle_item_create(access_token)
    encrypted_access_token = Webhookdb::Crypto.encrypt_value(
      Webhookdb::Crypto::Boxed.from_b64(self.service_integration.data_encryption_secret),
      Webhookdb::Crypto::Boxed.from_raw(access_token),
    ).base64
    payload = self._fetch_insert_payload(access_token)
    payload["encrypted_access_token"] = encrypted_access_token
    return payload
  end

  def _handle_item_refresh(item_id)
    plaid_item_row = self.readonly_dataset(timeout: :fast) { |ds| ds[plaid_id: item_id] }
    if plaid_item_row.nil?
      raise Webhookdb::RegressionModeSkip if Webhookdb.regression_mode?
      raise Webhookdb::InvalidPrecondition,
            "could not find Plaid item #{item_id} for integration #{self.service_integration.opaque_id}"
    end
    access_token = self.decrypt_item_row_access_token(plaid_item_row)
    return self._fetch_insert_payload(access_token)
  end

  def _fetch_insert_payload(access_token)
    begin
      resp = Webhookdb::Http.post(
        "#{self.service_integration.api_url}/item/get",
        {
          access_token:,
          client_id: self.service_integration.backfill_key,
          secret: self.service_integration.backfill_secret,
        },
        logger: self.logger,
      )
    rescue Webhookdb::Http::Error => e
      errtype = e.response.parsed_response["error_type"]
      return {"error" => e.response.body} if STORABLE_ERROR_TYPES.include?(errtype)
      raise Amigo::Retry::Retry, rand(20..59) if errtype == "RATE_LIMIT_EXCEEDED"
      raise e
    end
    body = resp.parsed_response
    # This is sort of duplicated with the denormalized columns list,
    # but requires merging different parts of the response into a single payload.
    # It's not worth trying to remove the duplication,
    # so manually create the enrichment shape which is used by the denormalized columns.
    return {
      "available_products" => self._nil_or_json(body.fetch("item").fetch("available_products")),
      "billed_products" => self._nil_or_json(body.fetch("item").fetch("billed_products")),
      "error" => self._nil_or_json(body.fetch("item").fetch("error")),
      "institution_id" => body.fetch("item").fetch("institution_id"),
      "update_type" => body.fetch("item").fetch("update_type"),
      "consent_expiration_time" => body.fetch("item").fetch("consent_expiration_time"),
      "status" => self._nil_or_json(body.fetch("status")),
    }
  end

  def decrypt_item_row_access_token(plaid_item_row)
    return Webhookdb::Crypto.decrypt_value(
      Webhookdb::Crypto::Boxed.from_b64(self.service_integration.data_encryption_secret),
      Webhookdb::Crypto::Boxed.from_b64(plaid_item_row.fetch(:encrypted_access_token)),
    ).raw
  end

  def _webhook_response(request)
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
    if self.service_integration.backfill_key.blank?
      step.output = %(Almost there. We will need to use the Plaid API to fetch data
about Plaid Items and other resources, so we need your Client Id and Secret.)
      return step.prompting("Plaid Client ID").backfill_key(self.service_integration)
    end
    if self.service_integration.backfill_secret.blank?
      step.output = %(And now your API secret, too.)
      return step.secret_prompt("Plaid Secret").backfill_secret(self.service_integration)
    end
    step.output = %(Excellent. We have made a URL available
that you must use for webhooks, both in Plaid and from your backend:

#{self._webhook_endpoint}

The secret to use for signing is:

#{self.service_integration.webhook_secret}

At this point, you are ready to follow the detailed instructions
found here: https://webhookdb.com/docs/plaid.

#{self._query_help_output})
    return step.completed
  end

  def calculate_backfill_state_machine
    return self.calculate_create_state_machine
  end
end
