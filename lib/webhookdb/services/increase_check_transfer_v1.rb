# frozen_string_literal: true

require "webhookdb/increase"
require "webhookdb/services/increase_v1_mixin"

class Webhookdb::Services::IncreaseCheckTransferV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::IncreaseV1Mixin

  # @return [Webhookdb::Services::Descriptor]
  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "increase_check_transfer_v1",
      ctor: ->(sint) { Webhookdb::Services::IncreaseCheckTransferV1.new(sint) },
      feature_roles: ["beta"],
      resource_name_singular: "Increase Check Transfer",
    )
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:increase_id, "text")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:account_id, "text", index: true),
      Webhookdb::Services::Column.new(:address_line1, "text"),
      Webhookdb::Services::Column.new(:address_city, "text"),
      Webhookdb::Services::Column.new(:address_state, "text"),
      Webhookdb::Services::Column.new(:address_zip, "text", index: true),
      Webhookdb::Services::Column.new(:amount, "integer", index: true),
      Webhookdb::Services::Column.new(:created_at, "timestamptz", index: true),
      Webhookdb::Services::Column.new(:mailed_at, "timestamptz"),
      Webhookdb::Services::Column.new(:recipient_name, "text"),
      Webhookdb::Services::Column.new(:status, "text"),
      Webhookdb::Services::Column.new(:submitted_at, "timestamptz", index: true),
      Webhookdb::Services::Column.new(:template_id, "text"),
      Webhookdb::Services::Column.new(:transaction_id, "text", index: true),
      Webhookdb::Services::Column.new(:updated_at, "timestamptz", index: true),
    ]
  end

  def _update_where_expr
    Sequel[self.table_sym][:updated_at] < Sequel[:excluded][:updated_at]
  end

  def _prepare_for_insert(body, **_kwargs)
    return nil unless Webhookdb::Increase.contains_desired_object(body, "check_transfer")
    obj_of_interest, updated = self._extract_obj_and_updated(body)
    return {
      data: obj_of_interest.to_json,
      account_id: obj_of_interest.fetch("account_id"),
      address_line1: obj_of_interest.fetch("address_line1"),
      address_city: obj_of_interest.fetch("address_city"),
      address_state: obj_of_interest.fetch("address_state"),
      address_zip: obj_of_interest.fetch("address_zip"),
      amount: obj_of_interest.fetch("amount"),
      created_at: obj_of_interest.fetch("created_at"),
      increase_id: obj_of_interest.fetch("id"),
      mailed_at: obj_of_interest.fetch("mailed_at"),
      recipient_name: obj_of_interest.fetch("recipient_name"),
      status: obj_of_interest.fetch("status"),
      submitted_at: obj_of_interest.fetch("submitted_at"),
      template_id: obj_of_interest.fetch("template_id"),
      transaction_id: obj_of_interest.fetch("transaction_id"),
      updated_at: updated,
    }
  end

  def _mixin_backfill_url
    return "#{self.service_integration.api_url}/check_transfers"
  end
end
