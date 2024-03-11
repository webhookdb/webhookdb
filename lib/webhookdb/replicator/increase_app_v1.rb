# frozen_string_literal: true

class Webhookdb::Replicator::IncreaseAppV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "increase_app_v1",
      ctor: self,
      feature_roles: [],
      resource_name_singular: "Increase App",
      resource_name_plural: "Increase App",
      supports_webhooks: true,
      supports_backfill: true,
      install_url: "#{Webhookdb.api_url}/increase",
      documentation_url: "https://docs.webhookdb.com/guides/increase/",
      description: "Replicate your Increase data to WebhookDB Cloud in one click using " \
                   "our [WebhookDB-Increase integration](https://docs.webhookdb.com/guides/increase).",
    )
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:ignore_id, INTEGER)
  end

  def _denormalized_columns
    return []
  end

  def _upsert_webhook(request, **kw)
    raise Webhookdb::InvalidPrecondition, "can only handle event payloads" unless request.body.fetch("type") == "event"
    if request.body.fetch("category") == "oauth_connection.deactivated"
      self.service_integration.destroy_self_and_all_dependents
      return nil
    end
    dispatchable = self.service_integration.dependents.select do |d|
      d.service_name == "increase_event_v1" || d.replicator.handle_event?(request.body)
    end
    dispatchable.each do |sint|
      sint.replicator.upsert_webhook(request, **kw)
    end
    return nil
  end

  def _fetch_backfill_page(*)
    return [], nil
  end

  def webhook_response(request)
    return Webhookdb::Increase.webhook_response(request, Webhookdb::Increase.webhook_secret)
  end

  def calculate_webhook_state_machine
    return self.calculate_backfill_state_machine
  end

  def calculate_backfill_state_machine
    step = Webhookdb::Replicator::StateMachineStep.new
    step.output = %(This replicator is managed automatically using OAuth through Increase.
Head over to #{self.descriptor.install_url} to learn more.)
    step.completed
    return step
  end

  def build_dependents
    org = self.service_integration.organization
    parent_descr = self.descriptor
    sints = self.service_integration.organization.available_replicators.
      select { |dd| dd.dependency_descriptor == parent_descr }.
      map do |dd|
      Webhookdb::ServiceIntegration.create_disambiguated(
        dd.name,
        organization: org,
        depends_on: self.service_integration,
      )
    end
    sints.
      select { |sint| sint.replicator.descriptor.supports_backfill? }.
      each { |sint| sint.replicator._enqueue_backfill_jobs(incremental: false) }
  end
end
