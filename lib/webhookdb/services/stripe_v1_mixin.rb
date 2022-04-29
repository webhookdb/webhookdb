# frozen_string_literal: true

require "webhookdb/stripe"

module Webhookdb::Services::StripeV1Mixin
  # When we are backfilling, we recieve information from the charge api, but when
  # we recieve a webhook we are getting that information from the events api. Because
  # of this, the data we get in each case will have a different shape. This conditional
  # at the beginning of the function accomodates that difference in shape and ensures
  # that information from a webhook will always supercede information obtained through
  # backfilling.
  def _extract_obj_and_updated(body)
    updated = 0
    obj_of_interest = body
    if body.fetch("object") == "event"
      updated = body.fetch("created")
      obj_of_interest = body.fetch("data").fetch("object")
    end
    return obj_of_interest, updated
  end

  def _mixin_backfill_url
    raise NotImplementedError
  end

  # this array describes which event this webhook should subscribe to
  # https://stripe.com/docs/api/events/types
  def _mixin_event_type_names
    raise NotImplementedError
  end

  def webhook_response(request)
    return Webhookdb::Stripe.webhook_response(request, self.service_integration.webhook_secret)
  end

  def calculate_create_state_machine
    step = Webhookdb::Services::StateMachineStep.new
    unless self.service_integration.webhook_secret.present?
      step.output = %{You are about to start reflecting #{self.resource_name_singular} info into webhookdb.
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
    step = Webhookdb::Services::StateMachineStep.new
    unless self.service_integration.backfill_key.present?
      step.output = %(In order to backfill #{self.resource_name_plural}, we need an API key.
From your Stripe Dashboard, go to Developers -> API Keys -> Restricted Keys -> Create Restricted Key.
Create a key with Read access to #{self.resource_name_plural}.
Submit, then copy the key when Stripe shows it to you:
      )
      return step.secret_prompt("Restricted Key").backfill_key(self.service_integration)
    end

    unless (result = self.verify_backfill_credentials).verified
      self.service_integration.service_instance.clear_backfill_information
      step.output = result.message
      return step.secret_prompt("Restricted Key").backfill_key(self.service_integration)
    end

    step.output = %(Great! We are going to start backfilling your #{self.resource_name_plural}.
#{self._query_help_output}
      )
    return step.completed
  end

  def _verify_backfill_403_err_msg
    return "It looks like that API Key does not have permission to access #{self.resource_name_singular} Records. " \
           "Please check the permissions by going to the list of restricted keys and " \
           "hovering over the information icon in the entry for this key. " \
           "Once you've verified or corrected the permissions for this key, " \
           "please reenter the API Key you just created:"
  end

  def _verify_backfill_401_err_msg
    return "It looks like that API Key is invalid. Please reenter the API Key you just created:"
  end

  def _verify_backfill_err_msg
    return "An error occurred. Please reenter the API Key you just created:"
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
