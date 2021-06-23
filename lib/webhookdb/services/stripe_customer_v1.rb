# frozen_string_literal: true

require "httparty"
require "stripe"
require "webhookdb/services/state_machine_step"

class Webhookdb::Services::StripeCustomerV1 < Webhookdb::Services::Base
  include Appydays::Loggable

  def webhook_response(request)
    return Webhookdb::Stripe.webhook_response(request)
  end

  def process_state_change(field, value)
    self.service_integration.db.transaction do
      self.service_integration.send("#{field}=", value)
      self.service_integration.save_changes
      case field
        when "webhook_secret"
          return self.calculate_create_state_machine(self.service_integration.organization)
        when "backfill_secret"
          return self.calculate_backfill_state_machine(self.service_integration.organization)
      else
          return
      end
    end
  end

  def calculate_create_state_machine(organization)
    step = Webhookdb::Services::StateMachineStep.new
    # if the service integration doesn't exist, create it with some standard values
    unless self.service_integration.webhook_secret.present?
      step.needs_input = true
      step.output = %{
You are about to start reflecting Stripe Customer info into webhookdb.
We've made an endpoint available for Stripe Customer webhooks:

https://api.webhookdb.com/v1/service_integrations/#{self.service_integration.opaque_id}

From your Stripe Dashboard, go to Developers -> Webhooks -> Add Endpoint.
Use the URL above, and choose all of the Customers events.
Then click Add Endpoint.

The page for the webhook will have a 'Signing Secret' section.
Reveal it, then copy the secret (it will start with `whsec_`).
      }
      step.prompt = "Paste or type your secret here:"
      step.prompt_is_secret = true
      step.post_to_url = "/v1/service_integrations/#{self.service_integration.opaque_id}/transition/webhook_secret"
      step.complete = false
      return step
    end
    step.needs_input = false
    step.output = %(
Great! WebhookDB is now listening for Stripe Customer webhooks.
You can query the database through your organization's Postgres connection string:

#{organization.readonly_connection_url}

You can also run a query through the CLI:

webhookdb db sql "SELECT * FROM stripe_customers_v1"

If you want to backfill existing Stripe Customers, we'll need your API key.
Run `webhookdb backfill #{self.service_integration.opaque_id}` to get started.
      )
    step.complete = true
    return step
  end

  def calculate_backfill_state_machine(organization)
    step = Webhookdb::Services::StateMachineStep.new
    # if the service integration doesn't exist, create it with some standard values
    unless self.service_integration.backfill_secret.present?
      step.needs_input = true
      step.output = %(
In order to backfill Stripe Customers, we need an API key.
From your Stripe Dashboard, go to Developers -> API Keys -> Restricted Keys -> Create Restricted Key.
Create a key with Read access to Customers.
Submit, then copy the key when Stripe shows it to you:
)
      step.prompt = "Paste or type your Restricted Key here:"
      step.prompt_is_secret = true
      step.post_to_url = "/v1/service_integrations/#{self.service_integration.opaque_id}/transition/backfill_secret"
      step.complete = false
      return step
    end

    step.needs_input = false
    step.output = %(
Great! We are going to start backfilling your Stripe Customer information.
Stripe allows us to backfill your entire history,
so you're in good shape.

You can query the database through your organization's Postgres connection string:

#{organization.readonly_connection_url}

You can also run a query through the CLI:

webhookdb db sql "SELECT * FROM stripe_customers_v1"
      )
    step.complete = true
    return step
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:stripe_id, "text")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:balance, "real"),
      Webhookdb::Services::Column.new(:created, "integer"),
      Webhookdb::Services::Column.new(:email, "text"),
      Webhookdb::Services::Column.new(:name, "text"),
      Webhookdb::Services::Column.new(:phone, "text"),
      Webhookdb::Services::Column.new(:updated, "integer"),
    ]
  end

  def _update_where_expr
    return Sequel[self.table_sym][:updated] < Sequel[:excluded][:updated]
  end

  def _prepare_for_insert(body)
    # When we are backfilling, we recieve information from the charge api, but when
    # we recieve a webhook we are getting that information from the events api. Because
    # of this, the data we get in each case will have a different shape. This conditional
    # at the beginning of the function accomodates that difference in shape and ensures
    # that information from a webhook will always supercede information obtained through
    # backfilling.
    updated = 0
    obj_of_interest = body
    if body["object"] == "event"
      updated = body["created"]
      obj_of_interest = body["data"]["object"]
    end
    return {
      data: obj_of_interest.to_json,
      balance: obj_of_interest["balance"],
      created: obj_of_interest["created"],
      email: obj_of_interest["email"],
      name: obj_of_interest["name"],
      phone: obj_of_interest["phone"],
      stripe_id: obj_of_interest["id"],
      updated: updated,
    }
  end

  def _fetch_backfill_page(pagination_token)
    unless (url = pagination_token)
      url = ""
    end
    url = "https://api.stripe.com/v1/customers" + url
    response = HTTParty.get(
      url,
      basic_auth: {username: self.service_integration.backfill_key},
      logger: self.logger,
    )
    self.logger.error "stripe charge backfilling", response
    raise response if response.code >= 300
    data = response.parsed_response
    if data["has_more"]
      last_item_id = data["data"][-1]["id"]
      next_page_param = "?starting_after=" + last_item_id
    end
    return data["data"], next_page_param
  end
end
