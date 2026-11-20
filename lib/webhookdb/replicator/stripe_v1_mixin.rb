# frozen_string_literal: true

require "webhookdb/stripe"

module Webhookdb::Replicator::StripeV1Mixin
  def _resource_and_event(request)
    body = request.body
    return body.fetch("data").fetch("object"), body if body.fetch("object") == "event"
    return body, nil
  end

  def _mixin_backfill_url
    raise NotImplementedError
  end

  # this array describes which event this webhook should subscribe to
  # https://stripe.com/docs/api/events/types
  def _mixin_event_type_names
    raise NotImplementedError
  end

  def _webhook_response(request)
    return Webhookdb::Stripe.webhook_response(request, self.service_integration.webhook_secret)
  end

  def _timestamp_column_name
    return :updated
  end

  def calculate_webhook_state_machine
    step = Webhookdb::Replicator::StateMachineStep.new
    unless self.service_integration.webhook_secret.present?
      step.output = %{You are about to start replicating #{self.resource_name_singular} info into WebhookDB.
We've made an endpoint available for #{self.resource_name_singular} webhooks:

#{self._webhook_endpoint}

From your Stripe Dashboard, go to Developers -> Webhooks -> Add Endpoint.
Use the URL above, and choose all of the following events:
  #{self._mixin_event_type_names.join("\n  ")}
Then click Add Endpoint.

The page for the webhook will have a 'Signing Secret' section.
Reveal it, then copy the secret (it will start with `whsec_`).
      }
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
    step = Webhookdb::Replicator::StateMachineStep.new
    unless self.service_integration.backfill_key.present?
      step.output = %(In order to backfill #{self.resource_name_plural}, we need an API key.
From your Stripe Dashboard, go to Developers -> API Keys -> Restricted Keys -> Create Restricted Key.
Create a key with Read access to #{self.restricted_key_resource_name}.
Submit, then copy the key when Stripe shows it to you:
      )
      return step.secret_prompt("Restricted Key").backfill_key(self.service_integration)
    end

    unless (result = self.verify_backfill_credentials).verified?
      msg = case result.http_error_status
        when 403
          self.service_integration.update(backfill_key: nil)
          "It looks like that API Key does not have permission to access #{self.resource_name_singular} Records. " \
            "Please check the permissions by going to the list of restricted keys and " \
            "hovering over the information icon in the entry for this key. " \
            "Once you've verified or corrected the permissions for this key, " \
            "please reenter the API Key you just created:"
          else
          self.clear_backfill_information
          "Something is wrong with your configuration. Please look over the instructions and try again."
      end
      return self.calculate_backfill_state_machine.with_output(msg)
    end

    step.output = %(Great! We are going to start backfilling your #{self.resource_name_plural}.
#{self._query_help_output}
      )
    return step.completed
  end

  def restricted_key_resource_name = self.resource_name_plural.gsub(/^Stripe /, "")

  def _fetch_backfill_page(pagination_token, **_kwargs)
    url = self._mixin_backfill_url
    url += pagination_token if pagination_token.present?
    response = Webhookdb::Http.get(
      url,
      basic_auth: {username: self.service_integration.backfill_key},
      logger: self.logger,
      timeout: Webhookdb::Stripe.http_timeout,
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
