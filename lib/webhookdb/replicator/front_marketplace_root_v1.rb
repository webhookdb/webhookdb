# frozen_string_literal: true

require "webhookdb/replicator/front_v1_mixin"

class Webhookdb::Replicator::FrontMarketplaceRootV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "front_marketplace_root_v1",
      ctor: self,
      feature_roles: [],
      resource_name_singular: "Front Auth",
      resource_name_plural: "Front Auth",
      supports_webhooks: true,
      description: "You can replicate your data to WebhookDB Cloud using the Front Marketplace.",
    )
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:ignore_id, INTEGER)
  end

  def _denormalized_columns
    return []
  end

  def _upsert_webhook(**_kwargs)
    raise NotImplementedError("This is a stub integration only for auth purposes.")
  end

  def build_dependents
    org = self.service_integration.organization
    conversation_sint = Webhookdb::ServiceIntegration.create_disambiguated(
      "front_conversation_v1",
      organization: org,
      depends_on: self.service_integration,
    )
    message_sint = Webhookdb::ServiceIntegration.create_disambiguated(
      "front_message_v1",
      organization: org,
      depends_on: self.service_integration,
    )
    conversation_sint.replicator.create_table
    message_sint.replicator.create_table
  end

  def calculate_webhook_state_machine
    return Webhookdb::Replicator::FrontV1Mixin.marketplace_only_state_machine
  end
end
