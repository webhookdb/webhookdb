# frozen_string_literal: true

require "grape/util/env"

module Webhookdb::Replicator::MyallocatorV1Mixin
  include Webhookdb::DBAdapter::ColumnTypes

  def _resource_and_event(request)
    return request.body, nil
  end

  def _timestamp_column_name
    return :row_updated_at
  end

  def _update_where_expr
    # TODO: think this over
    return self.qualified_table_sequel_identifier[:data] !~ Sequel[:excluded][:data]
  end

  def process_webhooks_synchronously?
    return true
  end

  def _webhook_response(request)
    (parsed_body = request.env[Grape::Env::API_REQUEST_BODY]) or
      raise Webhookdb::InvalidPrecondition, "expected request.env to have api.request.body, which is set by Grape"
    shared_secret = parsed_body["shared_secret"]
    matches = if shared_secret.nil?
                false
else
  ActiveSupport::SecurityUtils.secure_compare(
    self.service_integration.webhook_secret, shared_secret,
  )
end
    unless matches
      return Webhookdb::WebhookResponse.ok(json: {"ErrorCode" => 1153, "Error" => "Invalid shared secret"},
                                           status: 200,)
    end
    return Webhookdb::WebhookResponse.ok(status: 200)
  end

  # @return [Webhookdb::Replicator::StateMachineStep]
  def calculate_create_state_machine
    # can inherit the `.ASPXAUTH` piece of the cookie and the API url from the auth dependency
    if (step = self.calculate_dependency_state_machine_step(dependency_help: ""))
      return step
    end
    step = Webhookdb::Replicator::StateMachineStep.new
    step.output = %(Great! You are all set.

#{self._query_help_output(prefix: "Once data is available, you can query #{self.resource_name_plural}.")})
    return step.completed
  end

  # @return [Webhookdb::Replicator::StateMachineStep]
  def calculate_backfill_state_machine
    self.calculate_create_state_machine
  end

  def on_dependency_webhook_upsert(_replicator, _payload, *)
    return
  end
end
