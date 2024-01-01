# frozen_string_literal: true

module Webhookdb::Replicator::ConvertkitV1Mixin
  include Webhookdb::DBAdapter::ColumnTypes

  # ConvertKit gets a decent number of 5xx responses.
  # Wait for about 20 minutes before the job dies.
  def backfiller_server_error_retries = 10
  def backfiller_server_error_backoff = 121.seconds

  def _webhook_response(_request)
    # Webhook Authentication isn't supported
    return Webhookdb::WebhookResponse.ok
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:convertkit_id, BIGINT, data_key: "id")
  end

  def calculate_backfill_state_machine
    step = Webhookdb::Replicator::StateMachineStep.new
    if self.service_integration.backfill_secret.blank?
      step.output = %(Great! We've created your #{self.resource_name_plural} integration.

#{self.resource_name_singular} webhooks are not designed to mirror data, so to fill your database,
we need to use the API to make requests, which requires your API Secret.
#{Webhookdb::Convertkit::FIND_API_SECRET_HELP}
      )
      return step.secret_prompt("API Secret").backfill_secret(self.service_integration)
    end

    unless (result = self.verify_backfill_credentials).verified
      self.service_integration.replicator.clear_backfill_information
      step.output = result.message
      return step.secret_prompt("API Secret").backfill_secret(self.service_integration)
    end

    step.output = %(We'll start backfilling your #{self.resource_name_plural} now,
and they will show up in your database momentarily.
#{self._query_help_output}
    )
    return step.completed
  end

  def _verify_backfill_401_err_msg
    return "It looks like that API Secret is invalid. Please reenter the API Secret:"
  end

  def _verify_backfill_err_msg
    return "An error occurred. Please reenter the API Secret:"
  end

  # Converter for use with the denormalized columns
  CONV_FIND_CANCELED_AT = Webhookdb::Replicator::Column::IsomorphicProc.new(
    ruby: lambda do |_, resource:, **_|
      # Subscribers do not store a cancelation time (nor an updated at time),
      # so we derive and store it based on their state.
      # When they become inactive state, we set canceled_at,
      # and clear it when they are not active.
      # See the upsert_update_expr for Convertkit Subscriber for the details.
      resource.fetch("state") == "active" ? nil : Time.now
    end,
    sql: nil,
  )
end
