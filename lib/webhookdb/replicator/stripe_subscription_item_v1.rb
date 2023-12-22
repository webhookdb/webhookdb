# frozen_string_literal: true

require "stripe"
require "webhookdb/replicator/stripe_v1_mixin"

class Webhookdb::Replicator::StripeSubscriptionItemV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::StripeV1Mixin

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "stripe_subscription_item_v1",
      ctor: ->(sint) { Webhookdb::Replicator::StripeSubscriptionItemV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "Stripe Subscription Item",
      supports_webhooks: true,
      supports_backfill: true,
      api_docs_url: "https://stripe.com/docs/api/subscription_items",
    )
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:stripe_id, TEXT, data_key: "id")
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:created, TIMESTAMP, index: true, converter: :tsat),
      Webhookdb::Replicator::Column.new(:price, TEXT, index: true, data_key: ["price", "id"], optional: true),
      Webhookdb::Replicator::Column.new(:product, TEXT, index: true, data_key: ["price", "product"], optional: true),
      Webhookdb::Replicator::Column.new(:quantity, INTEGER),
      Webhookdb::Replicator::Column.new(:subscription, TEXT, index: true),
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
    return "https://api.stripe.com/v1/subscription_items"
  end

  def _mixin_event_type_names
    return []
  end
end
