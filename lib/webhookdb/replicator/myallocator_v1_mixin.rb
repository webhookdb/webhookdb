# frozen_string_literal: true

require "grape/util/env"

module Webhookdb::Replicator::MyallocatorV1Mixin
  include Webhookdb::DBAdapter::ColumnTypes

  CREATE_PROPERTY_PATH = "/CreateProperty"
  GET_BOOKING_PATHS = ["/GetBookingId", "/GetBookingList"].freeze
  GET_RATE_PLANS_PATH = "/GetRatePlans"
  GET_ROOMS_PATH = "/GetRoomTypes"
  GET_SUB_PROPERTIES_PATH = "/GetSubProperties"
  SETUP_PROPERTY_PATH = "/SetupProperty"

  def _resource_and_event(request)
    return request.body, nil
  end

  def _timestamp_column_name
    return :row_updated_at
  end

  def _update_where_expr
    # TODO: double check this with rob
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
  def calculate_webhook_state_machine
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
    self.calculate_webhook_state_machine
  end

  def on_dependency_webhook_upsert(_replicator, _payload, *)
    return
  end

  def get_dependency_replicator(dependency_name)
    dep_integrations = self.service_integration.recursive_dependencies.filter do |d|
      d.service_name == dependency_name
    end
    if dep_integrations.size > 1
      raise Webhookdb::InvalidPrecondition,
            "should only depend on one #{dependency_name} integration"
    end
    if dep_integrations.size.zero?
      raise Webhookdb::InvalidPrecondition,
            "should depend directly or indirectly on #{dependency_name} integration"
    end
    return dep_integrations.first.replicator
  end

  def get_parent_property_row(request)
    mya_property_id = request.body.fetch("mya_property_id")
    property_svc = self.get_dependency_replicator("myallocator_property_v1")
    property_row = property_svc.admin_dataset { |property_ds| property_ds[mya_property_id:] }
    return property_row
  end

  # TODO: write documentation string here
  def ota_creds_correct?(property_row, request)
    return true if request.path == CREATE_PROPERTY_PATH
    return (request.body.fetch("ota_property_id") == property_row[:ota_property_id]) &&
        (request.body.fetch("ota_property_password") == property_row[:ota_property_password])
  end
end
