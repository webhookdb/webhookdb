# frozen_string_literal: true

require "stripe"
require "webhookdb/services/stripe_v1_mixin"

class Webhookdb::Services::StripePayoutV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::StripeV1Mixin

  # @return [Webhookdb::Services::Descriptor]
  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "stripe_payout_v1",
      ctor: ->(sint) { Webhookdb::Services::StripePayoutV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "Stripe Payout",
    )
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:stripe_id, TEXT, data_key: "id")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:amount, INTEGER, index: true),
      Webhookdb::Services::Column.new(:arrival_date, TIMESTAMP, index: true, converter: :tsat),
      Webhookdb::Services::Column.new(:balance_transaction, TEXT, index: true),
      Webhookdb::Services::Column.new(:created, TIMESTAMP, index: true, converter: :tsat),
      Webhookdb::Services::Column.new(:destination, TEXT, index: true),
      Webhookdb::Services::Column.new(:failure_balance_transaction, TEXT, index: true),
      Webhookdb::Services::Column.new(:original_payout, TEXT, index: true),
      Webhookdb::Services::Column.new(:reversed_by, TEXT, index: true),
      Webhookdb::Services::Column.new(:statement_descriptor, TEXT),
      Webhookdb::Services::Column.new(:status, TEXT),
      Webhookdb::Services::Column.new(
        :updated,
        TIMESTAMP,
        index: true,
        data_key: "created",
        event_key: "created",
        converter: :tsat,
      ),
    ]
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:updated] < Sequel[:excluded][:updated]
  end

  def _mixin_backfill_url
    return "https://api.stripe.com/v1/payouts"
  end

  def _mixin_event_type_names
    return [
      "payout.canceled",
      "payout.created",
      "payout.failed",
      "payout.paid",
      "payout.updated",
    ]
  end
end
