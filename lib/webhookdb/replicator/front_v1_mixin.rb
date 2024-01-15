# frozen_string_literal: true

require "webhookdb/front"

module Webhookdb::Replicator::FrontV1Mixin
  def calculate_webhook_state_machine
    if (step = self.calculate_dependency_state_machine_step(dependency_help: ""))
      return step
     end
    step = Webhookdb::Replicator::StateMachineStep.new
    step.output = %(Great! WebhookDB is now listening for #{self.resource_name_singular} webhooks.)
    return step.completed
  end

  def _webhook_response(request)
    return Webhookdb::Front.webhook_response(request, Webhookdb::Front.app_secret)
  end

  def on_dependency_webhook_upsert(_replicator, _payload, *)
    return
  end

  def self.marketplace_only_state_machine
    step = Webhookdb::Replicator::StateMachineStep.new
    step.output = %(Front integrations can only be enabled through the Front App Store.
Head over to https://app.frontapp.com/settings/apps/details/webhookdb/overview to set up WebhookDB replication.)
    step.completed
    return step
  end
end
