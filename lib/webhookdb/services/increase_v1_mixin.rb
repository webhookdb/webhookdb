# frozen_string_literal: true

require "webhookdb/increase"

module Webhookdb::Services::IncreaseV1Mixin
  def _mixin_backfill_url
    raise NotImplementedError
  end

  def _webhook_response(request)
    return Webhookdb::Increase.webhook_response(request, self.service_integration.webhook_secret)
  end

  def _extract_obj_and_updated(body)
    return body.fetch("data"), body.fetch("created_at") if
      body.key?("event") && body.key?("event_id")
    return body, body.fetch("created_at")
  end

  def calculate_create_state_machine
    step = Webhookdb::Services::StateMachineStep.new
    # if the service integration doesn't exist, create it with some standard values
    unless self.service_integration.webhook_secret.present?
      step.output = %(You are about to start reflecting #{self.resource_name_plural} info into webhookdb.
We've made an endpoint available for #{self.resource_name_singular} webhooks:

#{self._webhook_endpoint}

From your Increase admin dashboard, go to Team Settings -> Webhooks.
In the "Webhook endpoint URL" field you can enter the URL above.
For the shared secret, you'll have to generate a strong password
(you can use '#{Webhookdb::Id.rand_enc(16)}')
and then enter it into the textbox.

Copy that shared secret value.
      )
      return step.secret_prompt("secret").webhook_secret(self.service_integration)
    end

    step.output = %(Great! WebhookDB is now listening for #{self.resource_name_singular} webhooks.
#{self._query_help_output}
In order to backfill existing #{self.resource_name_plural}, run this from a shell:

  #{self._backfill_command}
    )
    return step.completed
  end

  def calculate_backfill_state_machine
    step = Webhookdb::Services::StateMachineStep.new
    unless self.service_integration.backfill_key.present?
      step.output = %(In order to backfill #{self.resource_name_plural}, we need an API key.
From your Increase admin dashboard, go to Team Settings -> API Keys.
We'll need the Production key--copy that value to your clipboard.
      )
      return step.secret_prompt("API Key").backfill_key(self.service_integration)
    end

    unless (result = self.verify_backfill_credentials).verified
      self.service_integration.service_instance.clear_backfill_information
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

  def _fetch_backfill_page(pagination_token, **_kwargs)
    query = {}
    (query[:cursor] = pagination_token) if pagination_token.present?
    response = Webhookdb::Http.get(
      self._mixin_backfill_url,
      query,
      headers: {"Authorization" => ("Bearer " + self.service_integration.backfill_key)},
      logger: self.logger,
    )
    data = response.parsed_response
    next_page_param = data.dig("response_metadata", "next_cursor")
    return data["data"], next_page_param
  end
end
