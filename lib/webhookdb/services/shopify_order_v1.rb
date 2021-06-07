# frozen_string_literal: true

require "httparty"
require "webhookdb/shopify"

class Webhookdb::Services::ShopifyOrderV1 < Webhookdb::Services::Base
  include Appydays::Loggable

  def webhook_response(request)
    # info for debugging
    shopify_auth = request.env["HTTP_X_SHOPIFY_HMAC_SHA256"]
    log_params = {shopify_auth: shopify_auth, shopify_body: request.params}
    self.logger.debug "webhook hit shopify order endpoint", log_params

    return [401, {"Content-Type" => "application/json"}, '{"message": "missing hmac"}'] if shopify_auth.nil?
    request.body.rewind
    request_data = request.body.read
    verified = Webhookdb::Shopify.verify_webhook(request_data, shopify_auth, self.service_integration.webhook_secret)
    return [200, {"Content-Type" => "application/json"}, '{"o":"k"}'] if verified
    return [401, {"Content-Type" => "application/json"}, '{"message": "invalid hmac"}']
  end

  # rubocop:disable Lint/DuplicateBranch
  def process_state_change(field, value)
    # special handling for converting a shop name into an api url
    if field == "shop_name"
      # revisionist history
      field = "api_url"
      value = "https://#{value}.myshopify.com"
    end
    self.service_integration.db.transaction do
      self.service_integration.send("#{field}=", value)
      self.service_integration.save_changes
      case field
        when "webhook_secret"
          return self.calculate_create_state_machine(self.service_integration.organization)
        when "backfill_key"
          return self.calculate_backfill_state_machine(self.service_integration.organization)
        when "backfill_secret"
          return self.calculate_backfill_state_machine(self.service_integration.organization)
        when "api_url"
          return self.calculate_backfill_state_machine(self.service_integration.organization)
      else
          return
      end
    end
  end
  # rubocop:enable Lint/DuplicateBranch

  def calculate_create_state_machine(organization)
    step = Webhookdb::Services::StateMachineStep.new
    # if the service integration doesn't exist, create it with some standard values
    unless self.service_integration.webhook_secret.present?
      step.needs_input = true
      step.output = %(
You are about to start reflecting Shopify Order info into webhookdb.
We've made an endpoint available for Shopify Order webhooks:

https://api.webhookdb.com/v1/service_integrations/#{self.service_integration.opaque_id}

From your Shopify admin dashboard, go to Settings -> Notifications.
Scroll down to the Webhook Section. You will need to create a separate webhook for each Customer
event, but you can use the URL above and select JSON as the desired format for all of them.

At the very bottom of the page, you should see a signing secret that will be used to verify all webhooks.
Copy that value.
      )
      step.prompt = "Paste or type your secret here:"
      step.prompt_is_secret = true
      step.post_to_url = "/v1/service_integrations/#{self.service_integration.opaque_id}/transition/webhook_secret"
      step.complete = false
      return step
    end

    step.needs_input = false
    step.output = %(
Great! WebhookDB is now listening for Shopify Order webhooks.
You can query the database through your organization's Postgres connection string:

#{organization.readonly_connection_url}

You can also run a query through the CLI:

webhookdb db sql "SELECT * FROM shopify_orders_v1"

If you want to backfill existing Shopify Orders, we'll need your API key.
Run `webhookdb backfill #{self.service_integration.opaque_id}` to get started.
      )
    step.complete = true
    return step
  end

  def calculate_backfill_state_machine(organization)
    step = Webhookdb::Services::StateMachineStep.new
    # if the service integration doesn't exist, create it with some standard values
    unless self.service_integration.backfill_key.present?
      step.needs_input = true
      step.output = %(
In order to backfill Shopify Orders, we need an API key and password.
From your Shopify Dashboard, go to Apps and click the "Manage Private Apps" link at the bottom of the page.
Then click "Create Private App" and fill out the necessary information.
When you get to the "Admin API" section, select "Read Access" for the Order API and leave the rest as is.
Then hit "Save" and create the app.
You'll be presented with a page that has info about your app's credentials.
We need both the API key and password.
      )
      step.prompt = "Paste or type your API Key here:"
      step.prompt_is_secret = true
      step.post_to_url = "/v1/service_integrations/#{self.service_integration.opaque_id}/transition/backfill_key"
      step.complete = false
      return step
    end

    unless self.service_integration.backfill_secret.present?
      step.needs_input = true
      step.prompt = "Paste or type your password here:"
      step.prompt_is_secret = true
      step.post_to_url = "/v1/service_integrations/#{self.service_integration.opaque_id}/transition/backfill_secret"
      step.complete = false
      return step
    end

    unless self.service_integration.api_url.present?
      step.needs_input = true
      step.output = %(
Nice! Now we need the name of your shop so that we can construct the api url.
This is the name that is used by Shopify for URL purposes—it should be
in the top left corner of your Admin Dashboard next to the Shopify logo.
      )
      step.prompt = "Paste or type your shop name here:"
      step.prompt_is_secret = false
      step.post_to_url = "/v1/service_integrations/#{self.service_integration.opaque_id}/transition/shop_name"
      step.complete = false
      return step
    end

    step.needs_input = false
    step.output = %(
Great! We are going to start backfilling your Shopify Order information.
Please note that Shopify only allows us to have access to orders made in the last 60 days,
so this history will not be comprehensive.

You can query the database through your organization's Postgres connection string:

#{organization.readonly_connection_url}

You can also run a query through the CLI:

webhookdb db sql "SELECT * FROM shopify_orders_v1"
      )
    step.complete = true
    return step
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:shopify_id, "text")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:app_id, "text"),
      Webhookdb::Services::Column.new(:cancelled_at, "timestamptz"),
      Webhookdb::Services::Column.new(:cart_token, "text"),
      Webhookdb::Services::Column.new(:checkout_token, "text"),
      Webhookdb::Services::Column.new(:closed_at, "timestamptz"),
      Webhookdb::Services::Column.new(:created_at, "timestamptz"),
      Webhookdb::Services::Column.new(:customer_id, "text"),
      Webhookdb::Services::Column.new(:email, "text"),
      Webhookdb::Services::Column.new(:name, "text"),
      Webhookdb::Services::Column.new(:order_number, "integer"),
      Webhookdb::Services::Column.new(:phone, "text"),
      Webhookdb::Services::Column.new(:token, "text"),
      Webhookdb::Services::Column.new(:updated_at, "timestamptz"),
      Webhookdb::Services::Column.new(:user_id, "text"),
    ]
  end

  def _update_where_expr
    return Sequel[self.table_sym][:updated_at] < Sequel[:excluded][:updated_at]
  end

  def _prepare_for_insert(body)
    return {
      app_id: body["app_id"],
      cancelled_at: body["cancelled_at"],
      cart_token: body["cart_token"],
      checkout_token: body["checkout_token"],
      closed_at: body["closed_at"],
      created_at: body["created_at"],
      customer_id: body["customer"]["id"],
      email: body["email"],
      name: body["name"],
      order_number: body["order_number"],
      phone: body["phone"],
      shopify_id: body["id"],
      token: body["token"],
      updated_at: body["updated_at"],
      user_id: body["user_id"],
    }
  end

  def _fetch_backfill_page(pagination_token)
    url = if pagination_token.blank?
            self.service_integration.api_url + "/admin/api/2021-04/orders.json?status=any"
    else
      pagination_token
          end
    response = HTTParty.get(
      url,
      basic_auth: {username: self.service_integration.backfill_key,
                   password: self.service_integration.backfill_secret,},
      logger: self.logger,
    )
    raise response if response.code >= 300
    data = response.parsed_response
    next_link = nil
    if response.headers.key?("link")
      links = Webhookdb::Shopify.parse_link_header(response.headers["link"])
      next_link = links[:next] if links.key?(:next)
    end
    return data["orders"], next_link
  end
end
