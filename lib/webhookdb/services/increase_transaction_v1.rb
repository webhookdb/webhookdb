# frozen_string_literal: true

require "httparty"
require "webhookdb/increase"

class Webhookdb::Services::IncreaseTransactionV1 < Webhookdb::Services::Base
  include Appydays::Loggable

  def webhook_response(request)
    return Webhookdb::Increase.webhook_response(request, self.service_integration.webhook_secret)
  end

  def process_state_change(field, value)
    self.service_integration.db.transaction do
      self.service_integration.send("#{field}=", value)
      self.service_integration.save_changes
      case field
        when "webhook_secret"
          return self.calculate_create_state_machine(self.service_integration.organization)
        when "backfill_key"
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
      step.output = %(
You are about to start reflecting Increase Transaction info into webhookdb.
We've made an endpoint available for Increase Transaction webhooks:

https://api.webhookdb.com/v1/service_integrations/#{self.service_integration.opaque_id}

From your Increase admin dashboard, go to Team Settings -> Webhooks.
In the "Webhook endpoint URL" field you can enter the URL above.
For the shared secret, you'll have to generate a strong password and then enter it into the textbox.

Copy that shared secret value.
      )
      step.prompt = "Paste or type your secret here:"
      step.prompt_is_secret = true
      step.post_to_url = "/v1/service_integrations/#{self.service_integration.opaque_id}/transition/webhook_secret"
      step.complete = false
      return step
    end

    step.needs_input = false
    step.output = %(
Great! WebhookDB is now listening for Increase Transaction webhooks.
You can query the database through your organization's Postgres connection string:

#{organization.readonly_connection_url}

You can also run a query through the CLI:

webhookdb db sql "SELECT * FROM increase_transaction_v1"

If you want to backfill existing Increase Transactions, we'll need your API key.
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
In order to backfill Increase Transactions, we need an API key.
From your Increase admin dashboard, go to Team Settings -> API Keys.
We'll need the Production key--copy that value to your clipboard.
      )
      step.prompt = "Paste or type your API Key here:"
      step.prompt_is_secret = true
      step.post_to_url = "/v1/service_integrations/#{self.service_integration.opaque_id}/transition/backfill_key"
      step.complete = false
      return step
    end

    step.needs_input = false
    step.output = %(
Great! We are going to start backfilling your Increase Transaction information.

You can query the database through your organization's Postgres connection string:

#{organization.readonly_connection_url}

You can also run a query through the CLI:

webhookdb db sql "SELECT * FROM increase_transaction_v1"
      )
    step.complete = true
    return step
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:increase_id, "text")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:account_id, "text"),
      Webhookdb::Services::Column.new(:amount, "text"),
      Webhookdb::Services::Column.new(:date, "date"),
      Webhookdb::Services::Column.new(:route_id, "text"),
      Webhookdb::Services::Column.new(:updated_at, "timestamptz"),
    ]
  end

  def _update_where_expr
    Sequel[self.table_sym][:updated_at] < Sequel[:excluded][:updated_at]
  end

  def _prepare_for_insert(body, **_kwargs)
    obj_of_interest = Webhookdb::Increase.find_desired_object_data(body)
    return nil unless Webhookdb::Increase.contains_desired_object(obj_of_interest, "transaction")

    updated = if body.key?("event")
                # i.e. if this is a webhook
                body["created_at"]
    else
      obj_of_interest["created_at"]
              end

    return {
      account_id: obj_of_interest["account_id"],
      amount: obj_of_interest["amount"],
      date: obj_of_interest["date"],
      increase_id: obj_of_interest["id"],
      route_id: obj_of_interest["route_id"],
      updated_at: updated,
    }
  end

  def _fetch_backfill_page(pagination_token)
    url = if pagination_token.blank?
            "https://api.increase.com/transactions"
    else
      "https://api.increase.com/transactions?cursor=" + pagination_token
          end
    response = HTTParty.get(
      url,
      headers: {"Authorization" => ("Bearer " + self.service_integration.backfill_key)},
      logger: self.logger,
    )
    self.logger.error "increase transaction backfilling", response
    raise response if response.code >= 300
    data = response.parsed_response
    next_page_param = data["response_metadata"]["next_cursor"] if data["response_metadata"]["next_cursor"]
    return data["data"], next_page_param
  end
end
