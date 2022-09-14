# frozen_string_literal: true

module Webhookdb::Services::BookingpalV1Mixin
  # @return [Webhookdb::Services::BookingpalAuthV1]
  include Webhookdb::DBAdapter::ColumnTypes

  def _resource_and_event(request)
    return request.body || {}, nil
  end

  def _timestamp_column_name
    return :row_updated_at
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:row_updated_at] < Sequel[:excluded][:row_updated_at]
  end

  def process_webhooks_synchronously?
    return true
  end

  def _webhook_response(request)
    # TODO: what is the actual header name?
    auth = request.env["API_KEY"]

    return Webhookdb::WebhookResponse.error("missing auth header") if auth.nil?
    return Webhookdb::WebhookResponse.error("invalid auth header") if auth != self.service_integration.webhook_secret
    return Webhookdb::WebhookResponse.ok
  end

  # @return [Webhookdb::Services::StateMachineStep]
  def calculate_create_state_machine
    # can inherit the `.ASPXAUTH` piece of the cookie and the API url from the auth dependency
    if (step = self.calculate_dependency_state_machine_step(dependency_help: ""))
      return step
    end
    step = Webhookdb::Services::StateMachineStep.new
    step.output = %(Great! You are all set.

#{self._query_help_output(prefix: "Once data is available, you can query #{self.resource_name_plural}.")})
    return step.completed
  end

  # @return [Webhookdb::Services::StateMachineStep]
  def calculate_backfill_state_machine
    self.calculate_create_state_machine
  end

  def on_dependency_webhook_upsert(_service_instance, _payload, *)
    return
  end

  DEFAULTER_DELETED_AT = Webhookdb::Services::Column::IsomorphicProc.new(
    ruby: lambda { |resource|
      return Time.now if resource["request_method"] == "DELETE"
      return nil
    },
    # We are only using this specifically when we recieve a certain type of webhook--
    # otherwise we never want to backfill or populate a `deleted_at` value where there
    # is none.
    sql: -> {},
  )
end
