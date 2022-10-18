# frozen_string_literal: true

require "stripe"
require "webhookdb/replicator/stripe_v1_mixin"

class Webhookdb::Replicator::StripePriceV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::StripeV1Mixin

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "stripe_price_v1",
      ctor: ->(sint) { Webhookdb::Replicator::StripePriceV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "Stripe Price",
    )
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:stripe_id, TEXT, data_key: "id")
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:created, TIMESTAMP, index: true, converter: :tsat),
      Webhookdb::Replicator::Column.new(:interval, TEXT, data_key: ["recurring", "interval"]),
      Webhookdb::Replicator::Column.new(:product, TEXT),
      Webhookdb::Replicator::Column.new(:type, TEXT),
      Webhookdb::Replicator::Column.new(:unit_amount, TEXT),
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
    return "https://api.stripe.com/v1/prices"
  end

  def _mixin_event_type_names
    return [
      "price.created",
      "price.deleted",
      "price.updated",
    ]
  end
end
