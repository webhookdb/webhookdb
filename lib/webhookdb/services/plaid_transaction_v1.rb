# frozen_string_literal: true

require "webhookdb/backfiller"
require "webhookdb/crypto"
require "webhookdb/plaid"

class Webhookdb::Services::PlaidTransactionV1 < Webhookdb::Services::Base
  include Appydays::Loggable

  # @return [Webhookdb::Services::Descriptor]
  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "plaid_transaction_v1",
      ctor: Webhookdb::Services::PlaidTransactionV1,
      feature_roles: ["beta"],
      resource_name_singular: "Plaid Transaction",
      dependency_descriptor: Webhookdb::Services::PlaidItemV1.descriptor,
    )
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:plaid_id, "text")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:item_id, "text", index: true),
      Webhookdb::Services::Column.new(:account_id, "text"),
      Webhookdb::Services::Column.new(:amount, "text"),
      Webhookdb::Services::Column.new(:iso_currency_code, "text"),
      Webhookdb::Services::Column.new(:datetime, "timestamptz", index: true),
      Webhookdb::Services::Column.new(:authorized_datetime, "timestamptz"),
      Webhookdb::Services::Column.new(:removed_at, "timestamptz"),
    ]
  end

  def upsert_has_deps?
    return true
  end

  # In Plaid, webhooks are about notifications, not resources,
  # so the way we handle webhooks does not work for them.
  # Normally we'd do something like be backfill-only,
  # but we MUST handle Plaid Transaction webhooks because we do not
  # want to initiate our own backfills, as they cost customers money.
  def upsert_webhook(body:)
    return unless body.fetch("webhook_type") == "TRANSACTIONS"
    code = body.fetch("webhook_code")
    item_id = body.fetch("item_id")
    plaid_item_service = self.service_integration.depends_on.service_instance
    plaid_item_row = plaid_item_service.readonly_dataset { |ds| ds[plaid_id: item_id] }
    if plaid_item_row.nil?
      raise Webhookdb::InvalidPrecondition,
            "could not find Plaid item #{item_id} for integration #{self.service_integration.opaque_id}"
    end
    case code
      when "TRANSACTIONS_REMOVED"
        self._mark_transactions_removed(body.fetch("removed_transactions"))
      when "HISTORICAL_UPDATE"
        self.handle_historical_update(plaid_item_service, plaid_item_row)
    else
        self.handle_incremental_update(plaid_item_service, plaid_item_row)
    end
  end

  def handle_historical_update(plaid_item_service, plaid_item_row)
    self.backfill_plaid_item(plaid_item_service, plaid_item_row, 2.years.ago)
  end

  def handle_incremental_update(plaid_item_service, plaid_item_row)
    pagination_start_date = self.readonly_dataset do |ds|
      ds.where(item_id: plaid_item_row.fetch(:plaid_id)).max(:datetime)
    end
    self.backfill_plaid_item(plaid_item_service, plaid_item_row, pagination_start_date || 2.years.ago)
  end

  def _mark_transactions_removed(removed_ids)
    self.admin_dataset do |ds|
      ds.where(plaid_id: removed_ids).update(removed_at: Time.now)
      ds.where(plaid_id: removed_ids).each do |row|
        self._publish_rowupsert(row)
      end
    end
  end

  def _webhook_response(_request)
    raise NotImplementedError, "this integration does not verify webhooks (it should come through plaid items)"
  end

  def calculate_create_state_machine
    if (step = self.calculate_dependency_state_machine_step(dependency_help: ""))
      return step
    end
    step = Webhookdb::Services::StateMachineStep.new
    step.output = %(Great! If you have fully set up your Plaid Items integration,
including setting the 'webhook' parameter when you create Link tokens,
and updating existing items in Plaid to point to your webhook URL,
you are all set. If you have not, or you're not sure,
please check out https://webhookdb.com/docs/plaid for more detailed instructions.

#{self._query_help_output(prefix: 'Once data is available, you can query Plaid Transactions')})
    return step.completed
  end

  def calculate_backfill_state_machine
    step = Webhookdb::Services::StateMachineStep.new
    step.needs_input = false
    step.output = %(We cannot backfill Plaid Transactions because it would hit Plaid for every single
Plaid Item you have in WebhookDB, and could incur significant financial cost to your Plaid account.
Instead, you can send WebhookDB a webhook to start a backfill for specific Plaid Items.

Please refer to https://webhookdb.com/docs/plaid#backfill-history for more detailed instructions.

#{self._query_help_output(prefix: 'Once data is available, you can query the Plaid Transactions table')})
    step.error_code = "plaid_transaction_nobackfill"
    step.complete = true
    return step
  end

  def on_dependency_webhook_upsert(_service_instance, _payload, *)
    # We do not want to automatically get transactions,
    # since it would cost the customer money.
    # However we do need to override this.
    return
  end

  # @param plaid_item_service [Webhookdb::Services::PlaidItemV1]
  # @param plaid_item_row [Hash<Symbol, Any>]
  def backfill_plaid_item(plaid_item_service, plaid_item_row, start_date)
    item_integration = plaid_item_service.service_integration
    raise Webhookdb::Services::CredentialsMissing if
      item_integration.backfill_key.blank? ||
        item_integration.backfill_secret.blank? ||
        item_integration.api_url.blank?

    plaid_access_token = Webhookdb::Crypto.decrypt_value(
      Webhookdb::Crypto::Boxed.from_b64(item_integration.data_encryption_secret),
      Webhookdb::Crypto::Boxed.from_b64(plaid_item_row.fetch(:encrypted_access_token)),
    ).raw

    backfiller = TransactionBackfiller.new(
      item_svc: plaid_item_service,
      transaction_svc: self,
      plaid_item_id: plaid_item_row.fetch(:plaid_id),
      plaid_access_token:,
    )
    backfiller.backfill(start_date)
  end

  class TransactionBackfiller < Webhookdb::Backfiller
    def initialize(item_svc:, transaction_svc:, plaid_item_id:, plaid_access_token:)
      @item_svc = item_svc
      @transaction_svc = transaction_svc
      @plaid_item_id = plaid_item_id
      @plaid_access_token = plaid_access_token
      @api_url = @item_svc.service_integration.api_url
      super()
    end

    def handle_item(body)
      inserting = {
        plaid_id: body.fetch("transaction_id"),
        item_id: @plaid_item_id,
        data: body.to_json,
        account_id: body.fetch("account_id"),
        amount: body.fetch("amount"),
        iso_currency_code: body.fetch("iso_currency_code"),
        datetime: body.fetch("datetime"),
        authorized_datetime: body.fetch("authorized_datetime"),
      }
      upserted_rows = @transaction_svc.admin_dataset do |ds|
        ds.insert_conflict(
          target: :plaid_id,
          update: inserting,
        ).insert(inserting)
      end
      row_changed = upserted_rows.present?
      @transaction_svc._publish_rowupsert(inserting) if row_changed
    end

    def fetch_backfill_page(pagination_token, last_backfilled:)
      count = Webhookdb::Plaid.page_size
      offset = pagination_token.present? ? pagination_token : 0
      url = @api_url + "/transactions/get"

      response = Webhookdb::Http.post(
        url,
        {
          client_id: @item_svc.service_integration.backfill_key,
          secret: @item_svc.service_integration.backfill_secret,
          access_token: @plaid_access_token,
          start_date: last_backfilled.strftime("%Y-%m-%d"),
          end_date: Time.now.tomorrow.strftime("%Y-%m-%d"),
          options: {
            count:,
            offset:,
          },
        },
        logger: @transaction_svc.logger,
      )
      data = response.parsed_response["transactions"]
      return data, nil if data.size < count
      return data, offset + count
    end
  end
end
