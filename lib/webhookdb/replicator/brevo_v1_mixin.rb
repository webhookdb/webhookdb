# frozen_string_literal: true

require "webhookdb/brevo"

module Webhookdb::Replicator::BrevoV1Mixin
  BREVO_HEADER_PREFIX = 'BREVO'

  def _mixin_backfill_url
    raise NotImplementedError
  end

  def _webhook_response(request)
    return Webhookdb::Brevo.webhook_response(request)
  end

  def _timestamp_column_name
    return :date
  end

  def process_state_change(field, value)
    # special handling for having a default value for api url
    value = "https://api.brevo.com/v3" if field == "api_url" && value == ""
    return super(field, value)
  end

  def calculate_webhook_state_machine
    step = Webhookdb::Replicator::StateMachineStep.new
    # If the service integration doesn't exist, create it with some standard values
    unless self.service_integration.webhook_secret.present?
      step.output = %(You are about to start replicating #{self.resource_name_plural} info into WebhookDB.
We've made an endpoint available for #{self.resource_name_singular} webhooks:

#{self._webhook_endpoint}

From your Brevo "My Account Dashboard", go to Transactional --> Email -> Settings --> Webhook.
Click "Add a new webhook", and in the "URL to call" field you can enter the URL above.

Click <Enter> to continue.
      )
    end

    step.needs_input = true

    step.output = %(Great! WebhookDB is now listening for #{self.resource_name_singular} webhooks.
#{self._query_help_output}
In order to backfill existing #{self.resource_name_plural}, run this from a shell:

  #{self._backfill_command}
    )

    return step.completed
  end

  def calculate_backfill_state_machine
    step = Webhookdb::Replicator::StateMachineStep.new
    unless self.service_integration.backfill_key.present?
      step.output = %(In order to backfill #{self.resource_name_plural}, we need an API key.
If you don't have one, you can generate it by going to your Brevo "My Account Dashboard", click your profile name's dropdown,
then go to SMTP & API -> Generate a new API key.
      )
      return step.secret_prompt("API Key").backfill_key(self.service_integration)
    end

    unless self.service_integration.api_url.present?
      step.output = %(Great. Now we want to make sure we're sending API requests to the right place.
For Brevo, the API root url is:

https://api.brevo.com/v3

Leave blank to use the default or paste the answer into this prompt.
      )
      return step.prompting("API url").api_url(self.service_integration)
    end

    unless (result = self.verify_backfill_credentials).verified
      self.service_integration.replicator.clear_backfill_information
      step.output = result.message
      return step.secret_prompt("API Key").backfill_key(self.service_integration)
    end

    step.needs_input = false
    step.output = %(Great! We are going to start backfilling your #{self.resource_name_plural}.
#{self._query_help_output}
      )
    step.complete = true

    return step
  end

  def _verify_backfill_401_err_msg
    return "It looks like that API Key is invalid. Please reenter the API Key you just created:"
  end

  def _verify_backfill_err_msg
    return "An error occurred. Please reenter the API Key you just created:"
  end

  # Fetches the last 90 days (maximum) worth of events, including today's.
  # e.g., https://api.brevo.com/v3/smtp/statistics/events?days=90
  # All types of events will be included.
  def _fetch_backfill_page(*)
    query = {days: 90}
    response = Webhookdb::Http.get(
      self._mixin_backfill_url,
      query,
      headers: {"api-key" => self.service_integration.backfill_key},
      logger: self.logger,
      timeout: Webhookdb::Increase.http_timeout,
    )
    return response.parsed_response["events"]
  end
end
