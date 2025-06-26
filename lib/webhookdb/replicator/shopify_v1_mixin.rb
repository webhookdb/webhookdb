# frozen_string_literal: true

require "webhookdb/shopify"

module Webhookdb::Replicator::ShopifyV1Mixin
  def _mixin_backfill_url
    raise NotImplementedError
  end

  def _mixin_backfill_hashkey
    raise NotImplementedError
  end

  def _mixin_backfill_warning
    raise NotImplementedError
  end

  def _timestamp_column_name
    return :updated_at
  end

  # For Shopify endpoints the object and webhook have the same shape—the webhook is simply the updated object
  def _resource_and_event(request)
    return request.body, nil
  end

  def _webhook_response(request)
    # info for debugging
    shopify_auth = request.env["HTTP_X_SHOPIFY_HMAC_SHA256"]
    log_params = {shopify_auth:, shopify_body: request.params}
    self.logger.debug "webhook hit shopify endpoint", log_params

    return Webhookdb::WebhookResponse.error("missing hmac") if shopify_auth.nil?
    request_data = Webhookdb::Http.rewind_request_body(request).read
    verified = Webhookdb::Shopify.verify_webhook(request_data, shopify_auth, self.service_integration.webhook_secret)
    return Webhookdb::WebhookResponse.ok if verified
    return Webhookdb::WebhookResponse.error("invalid hmac")
  end

  def process_state_change(field, value)
    # special handling for converting a shop name into an api url
    if field == "shop_name"
      # revisionist history
      field = "api_url"
      value = "https://#{value}.myshopify.com"
    end
    return super
  end

  def calculate_webhook_state_machine
    step = Webhookdb::Replicator::StateMachineStep.new
    # if the service integration doesn't exist, create it with some standard values
    unless self.service_integration.webhook_secret.present?
      step.needs_input = true
      step.output = %(You are about to start replicating #{self.resource_name_plural} into WebhookDB.
We've made an endpoint available for #{self.resource_name_singular} webhooks:

#{self._webhook_endpoint}

From your Shopify admin dashboard, go to Settings -> Notifications.
Scroll down to the Webhook Section.
You will need to create a separate webhook for each #{self.resource_name_singular} event,
but you can use the URL above and select JSON as the desired format for all of them.

At the very bottom of the page, you should see a signing secret that will be used to verify all webhooks.
Copy that value.)
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
      step.output =
        %(In order to backfill #{self.resource_name_plural}, we need an API key and password
(file an issue at #{Webhookdb.oss_repo_url} if you need token support).

- From your Shopify Dashboard, go to Apps and click the "Manage Private Apps" link at the bottom of the page.
- Then click "Create Private App" and fill out the necessary information.
- When you get to the "Admin API" section,
  select "Read Access" for the #{self.resource_name_singular} API and leave the rest as is.
- Then hit "Save" and create the app.
- You'll be presented with a page that has info about your app's credentials.

We need both the API Key and Password.)
      return step.secret_prompt("API Key").backfill_key(self.service_integration)
    end

    unless self.service_integration.backfill_secret.present?
      return step.secret_prompt("Password").backfill_secret(self.service_integration)
    end

    unless self.service_integration.api_url.present?
      step.output = %(Nice! Now we need the name of your shop so that we can construct the api url.
This is the name that is used by Shopify for URL purposes.
It should be in the top left corner of your Admin Dashboard next to the Shopify logo.)
      step.post_to_url = self.service_integration.authed_api_path + "/transition/shop_name"
      return step.prompting("Shop Name")
    end

    # we check backfill credentials *after* entering the api_url because it is required to establish the auth connection
    unless (result = self.verify_backfill_credentials).verified?
      msg = case result.http_error_status
        when 401
          # For a 401, reset the whole thing and try again.
          self.service_integration.replicator.clear_backfill_information
          "It looks like that API Key/Access Token combination is invalid. " \
            "Please check over instructions and try again."
        when 403
          # For a 403, we just need a new access token with better permissions.
          self.service_integration.update(backfill_key: nil)
          "It looks like that API Key does not have permission to access #{self.resource_name_singular} Records. " \
            "Please check the permissions by going to your private app page and " \
            "looking at the list of active permissions. " \
            "Once you've verified or corrected the permissions for this key, " \
            "please reenter the API Key you just created."
        else
          # For an unhandled error, ask them to try again.
          self.service_integration.update(backfill_key: nil)
          "An error occurred. Please reenter the API Key you just created and try again."
      end
      return self.calculate_backfill_state_machine.with_output(msg)
    end

    step.output = %(Great! We are going to start backfilling your #{self.resource_name_plural}.
#{self._mixin_backfill_warning}
#{self._query_help_output})
    return step.completed
  end

  def _fetch_backfill_page(pagination_token, **_kwargs)
    url = if pagination_token.blank?
            self.service_integration.api_url + self._mixin_backfill_url
    else
      pagination_token
    end
    response = Webhookdb::Http.get(
      url,
      basic_auth: {username: self.service_integration.backfill_key,
                   password: self.service_integration.backfill_secret,},
      logger: self.logger,
      timeout: Webhookdb::Shopify.http_timeout,
    )
    data = response.parsed_response
    next_link = nil
    if response.headers.key?("link")
      links = Webhookdb::Shopify.parse_link_header(response.headers["link"])
      next_link = links[:next] if links.key?(:next)
    end
    return data[self._mixin_backfill_hashkey], next_link
  end
end
