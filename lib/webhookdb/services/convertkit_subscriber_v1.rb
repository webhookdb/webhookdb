# frozen_string_literal: true

require "time"
require "webhookdb/convertkit"

class Webhookdb::Services::ConvertkitSubscriberV1 < Webhookdb::Services::Base
  include Appydays::Loggable

  def _webhook_verified?(_request)
    # Webhook Authentication isn't supported
    return true
  end

  def process_state_change(field, value)
    self.service_integration.db.transaction do
      self.service_integration.send("#{field}=", value)
      self.service_integration.save_changes
      case field
        when "backfill_secret"
          self.create_webhooks
          return self.calculate_backfill_state_machine(self.service_integration.organization)
      else
          return
      end
    end
  end

  def create_webhooks
    # ConvertKit has made several other webhooks available for the subscriber object, but they all have required
    # parameters that are pks of other objects that webhookdb knows nothing about.
    self.create_activate_webhook
    self.create_unsubscribe_webhook
  end

  def create_activate_webhook
    Webhookdb::Http.post(
      "https://api.convertkit.com/v3/automations/hooks",
      {
        "api_secret" => self.service_integration.backfill_secret,
        "target_url" => "https://api.webhookdb.com/v1/service_integrations/#{self.service_integration.opaque_id}",
        "event" => {"name" => "subscriber.subscriber_activate"},
      },
      logger: self.logger,
    )

  end

  def create_unsubscribe_webhook
    Webhookdb::Http.post(
      "https://api.convertkit.com/v3/automations/hooks",
      {
        "api_secret" => self.service_integration.backfill_secret,
        "target_url" => "https://api.webhookdb.com/v1/service_integrations/#{self.service_integration.opaque_id}",
        "event" => {"name" => "subscriber.subscriber_unsubscribe"},
      },
      logger: self.logger,
    )
  end

  def calculate_create_state_machine(organization)
    step = Webhookdb::Services::StateMachineStep.new
    step.needs_input = false
    step.output = %(
Great! We've created your ConvertKit Subscriber Service Integration.

You can query the database through your organization's Postgres connection string:

#{organization.readonly_connection_url}

You can also run a query through the CLI:

webhookdb db sql "SELECT * FROM #{self.service_integration.table_name}"

ConvertKit's webhook support is spotty, so to fill your database,
we need to set up backfill functionality.

Run `webhookdb backfill #{self.service_integration.opaque_id}` to get started.
      )
    step.complete = true
    return step
  end

  def calculate_backfill_state_machine(_organization)
    step = Webhookdb::Services::StateMachineStep.new
    if self.service_integration.backfill_secret.blank?
      step.needs_input = true
      step.output = %(
In order to backfill ConvertKit Subscribers, we need your API secret.

From your ConvertKit Dashboard, go to your advanced account settings,
at https://app.convertkit.com/account_settings/advanced_settings.
Under the API Header you should be able to see your API secret, just under your API Key.

Copy that API secret.
      )
      step.prompt = "Paste or type your API secret here:"
      step.prompt_is_secret = true
      step.post_to_url = "/v1/service_integrations/#{self.service_integration.opaque_id}/transition/backfill_secret"
      step.complete = false
      return step
    end
    step.needs_input = false
    step.output = %(
Great! We are going to start backfilling your ConvertKit Subscriber information.
      )
    step.complete = true
    return step
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:convertkit_id, "text")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:created_at, "timestamptz"),
      Webhookdb::Services::Column.new(:email_address, "text"),
      Webhookdb::Services::Column.new(:first_name, "text"),
      Webhookdb::Services::Column.new(:last_name, "text"),
      Webhookdb::Services::Column.new(:state, "text"),
    ]
  end

  def _update_where_expr
    # The subscriber resource does not have an `updated_at` field
    return Sequel[self.table_sym][:created_at] < Sequel[:excluded][:created_at]
  end

  def _prepare_for_insert(body, **_kwargs)
    return {
      convertkit_id: body["id"],
      created_at: body["created_at"],
      email_address: body["email_address"],
      first_name: body["first_name"],
      last_name: body["fields"]["last_name"],
      state: body["state"],
    }
  end

  def _fetch_backfill_page(pagination_token)
    pagination_token ||= ["subscribed", 1]
    list_being_iterated, page = pagination_token

    url = "https://api.convertkit.com/v3/subscribers?api_secret=#{self.service_integration.backfill_secret}&page=#{page}"
    url += "&sort_order=cancelled_at" if list_being_iterated == "cancelled"

    response = Webhookdb::Http.get(url, logger: self.logger)
    data = response.parsed_response
    current_page = data["page"]
    total_pages = data["total_pages"]
    subs = data["subscribers"]

    if current_page < total_pages
      # If we still have pages on this list, go to the next one
      return subs, [list_being_iterated, current_page + 1]
    end
    if list_being_iterated == "subscribed"
      # If we are done with the 'subscribed' list, we can now iterate cancelled
      return subs, ["cancelled", 1]
    end
    # Otherwise, we're at the last page of our canceled subscribers list
    return subs, nil
  end
end
