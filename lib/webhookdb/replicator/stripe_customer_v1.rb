# frozen_string_literal: true

require "stripe"
require "webhookdb/replicator/stripe_v1_mixin"

class Webhookdb::Replicator::StripeCustomerV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::StripeV1Mixin

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "stripe_customer_v1",
      ctor: ->(sint) { Webhookdb::Replicator::StripeCustomerV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "Stripe Customer",
    )
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:stripe_id, TEXT, data_key: "id")
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:balance, INTEGER, index: true),
      Webhookdb::Replicator::Column.new(:created, TIMESTAMP, index: true, event_key: "created", converter: :tsat),
      Webhookdb::Replicator::Column.new(:email, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:name, TEXT),
      Webhookdb::Replicator::Column.new(:phone, TEXT, index: true),
      Webhookdb::Replicator::Column.new(
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
    return "https://api.stripe.com/v1/customers"
  end

  def _mixin_event_type_names
    return [
      "customer.created",
      "customer.deleted",
      "customer.updated",
    ]
  end
end
