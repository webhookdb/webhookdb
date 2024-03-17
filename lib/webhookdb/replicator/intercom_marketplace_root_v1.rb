# frozen_string_literal: true

class Webhookdb::Replicator::IntercomMarketplaceRootV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "intercom_marketplace_root_v1",
      ctor: self,
      feature_roles: ["intercom"],
      resource_name_singular: "Intercom Auth",
      resource_name_plural: "Intercom Auth",
      supports_backfill: true,
      description: "You can replicate your Intercom data to WebhookDB Cloud in one click using  " \
                   "the [Intercom App Store](https://www.intercom.com/app-store).",
    )
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:ignore_id, INTEGER)
  end

  def _denormalized_columns
    return []
  end

  def _upsert_webhook(**_kwargs) = raise NotImplementedError("This is a stub integration only for auth purposes.")

  def _fetch_backfill_page(*)
    return [], nil
  end

  def webhook_response(_request) = raise NotImplementedError("This is a stub integration only for auth purposes.")

  def calculate_backfill_state_machine
    step = Webhookdb::Replicator::StateMachineStep.new
    step.output = "This integration cannot be modified through the command line."
    step.completed
    return step
  end

  def build_dependents
    org = self.service_integration.organization
    contact_sint = Webhookdb::ServiceIntegration.create_disambiguated(
      "intercom_contact_v1",
      organization: org,
      depends_on: self.service_integration,
    )
    conversation_sint = Webhookdb::ServiceIntegration.create_disambiguated(
      "intercom_conversation_v1",
      organization: org,
      depends_on: self.service_integration,
    )
    contact_sint.replicator._enqueue_backfill_jobs(incremental: true)
    conversation_sint.replicator._enqueue_backfill_jobs(incremental: true)
  end
end
