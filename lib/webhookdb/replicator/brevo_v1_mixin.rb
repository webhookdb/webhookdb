# frozen_string_literal: true

require "webhookdb/brevo"

module Webhookdb::Replicator::BrevoV1Mixin
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
    if self.service_integration.webhook_secret.blank?
      step.output = %(You are about to set up webhooks for #{self.resource_name_plural}.

Use this Webhook URL: #{self._webhook_endpoint}

From your Brevo "My Account Dashboard", go to Transactional --> Email -> Settings --> Webhook.
Click "Add a new webhook", and in the "URL to call" field you can enter the URL above.
      )
      step.set_prompt("Press Enter after Save Webhook succeeds:")
      step.transition_field(self.service_integration, "noop_create")
      self.service_integration.update(webhook_secret: "placeholder")
      return step
    end
    step.output = %(
Great! WebhookDB is now listening for #{self.resource_name_singular} webhooks.

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
then go to SMTP & API -> Generate a new API key.)
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

  # See https://developers.brevo.com/reference/getemaileventreport-1
  # All types of events will be included.
  def _fetch_backfill_page(pagination_token, last_backfilled:)
    today = Time.now.utc.to_date
    query = {limit: 100, endDate: today}
    min_start_date = today - 90.days
    query[:startDate] = if last_backfilled.nil?
      min_start_date
    else
      [last_backfilled_at, min_start_date].max
    end
    query[:offset] = if pagination_token.present?
      pagination_token
    else
      0
    end
    response = Webhookdb::Http.get(
      self._mixin_backfill_url,
      query,
      headers: {"api-key" => self.service_integration.backfill_key},
      logger: self.logger,
      timeout: Webhookdb::Increase.http_timeout,
    )
    data = response.parsed_response
    events = data.fetch('events', [])
    has_next_page = events.present?
    next_page_offset = has_next_page ? query[:offset] + 100 : nil
    return events, next_page_offset
  end
end
