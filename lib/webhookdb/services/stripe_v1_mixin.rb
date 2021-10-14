# frozen_string_literal: true

require "webhookdb/stripe"

module Webhookdb::Services::StripeV1Mixin
  def _mixin_name_singular
    raise NotImplementedError
  end

  def _mixin_name_plural
    raise NotImplementedError
  end

  def _mixin_backfill_url
    raise NotImplementedError
  end

  def webhook_response(request)
    return Webhookdb::Stripe.webhook_response(request, self.service_integration.webhook_secret)
  end

  def calculate_create_state_machine
    step = Webhookdb::Services::StateMachineStep.new
    unless self.service_integration.webhook_secret.present?
      step.output = %{
You are about to start reflecting #{self._mixin_name_singular} info into webhookdb.
We've made an endpoint available for #{self._mixin_name_singular} webhooks:

#{self._webhook_endpoint}

From your Stripe Dashboard, go to Developers -> Webhooks -> Add Endpoint.
Use the URL above, and choose all of the Charge events.
Then click Add Endpoint.

The page for the webhook will have a 'Signing Secret' section.
Reveal it, then copy the secret (it will start with `whsec_`).
      }
      return step.secret_prompt("secret").webhook_secret(self.service_integration)
    end

    step.output = %(
Great! WebhookDB is now listening for #{self._mixin_name_singular} webhooks.
#{self._query_help_output}
In order to backfill existing #{self._mixin_name_plural}, run this from a shell:

  #{self._backfill_command}
    )
    return step.completed
  end

  def calculate_backfill_state_machine
    step = Webhookdb::Services::StateMachineStep.new
    unless self.service_integration.backfill_secret.present?
      step.output = %(
In order to backfill #{self._mixin_name_plural}, we need an API key.
From your Stripe Dashboard, go to Developers -> API Keys -> Restricted Keys -> Create Restricted Key.
Create a key with Read access to #{self._mixin_name_plural}.
Submit, then copy the key when Stripe shows it to you:
      )
      return step.secret_prompt("Restricted Key").backfill_secret(self.service_integration)
    end

    step.output = %(
Great! We are going to start backfilling your #{self._mixin_name_plural}.
#{self._query_help_output}
      )
    return step.completed
  end

  def _fetch_backfill_page(pagination_token, **_kwargs)
    url = self._mixin_backfill_url
    url += pagination_token if pagination_token.present?
    response = Webhookdb::Http.get(
      url,
      basic_auth: {username: self.service_integration.backfill_key},
      logger: self.logger,
    )
    data = response.parsed_response
    next_page_param = nil
    if data["has_more"]
      last_item_id = data["data"][-1]["id"]
      next_page_param = "?starting_after=" + last_item_id
    end
    return data["data"], next_page_param
  end
end
