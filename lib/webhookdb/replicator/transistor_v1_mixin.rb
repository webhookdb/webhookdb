# frozen_string_literal: true

module Webhookdb::Replicator::TransistorV1Mixin
  include Webhookdb::DBAdapter::ColumnTypes

  def _webhook_response(_request)
    # As of 9/15/21 there is no way to verify authenticity of these webhooks
    return Webhookdb::WebhookResponse.ok
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:transistor_id, TEXT, data_key: "id")
  end

  def _timestamp_column_name
    return :updated_at
  end

  def _resource_and_event(request)
    body = request.body
    return body["data"], body if body.key?("data")
    return body, nil
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:updated_at] < Sequel[:excluded][:updated_at]
  end

  def calculate_backfill_state_machine
    step = Webhookdb::Replicator::StateMachineStep.new
    if self.service_integration.backfill_key.blank?
      step.output = %(Great! We've created your #{self.resource_name_plural} integration.

Transistor does not support #{self.resource_name_singular} webhooks, so to fill your database,
we need to use the API to make requests, which requires your API Key.

From your Transistor dashboard, go to the "Your Account" page,
at https://dashboard.transistor.fm/account
On the left side of the bottom of the page you should be able to see your API key.

Copy that API key.
      )
      return step.secret_prompt("API Key").backfill_key(self.service_integration)
    end

    unless (result = self.verify_backfill_credentials).verified
      self.service_integration.replicator.clear_backfill_information
      step.output = result.message
      return step.secret_prompt("API Key").backfill_key(self.service_integration)
    end

    step.output = %(Great! We are going to start replicating your #{self.resource_name_plural}.
#{self._query_help_output}
    )
    return step.completed
  end

  def _verify_backfill_401_err_msg
    return "It looks like that API Key is invalid. Please reenter the API Key you just created:"
  end

  def _verify_backfill_err_msg
    return "An error occurred. Please reenter the API Key you just created:"
  end
end
