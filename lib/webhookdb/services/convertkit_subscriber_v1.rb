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
    step = super
    self._create_webhooks if field == "backfill_secret"
    return step
  end

  def _create_webhooks
    # ConvertKit has made several other webhooks available for the subscriber object, but they all have required
    # parameters that are pks of other objects that webhookdb knows nothing about.
    Webhookdb::Http.post(
      "https://api.convertkit.com/v3/automations/hooks",
      {
        "api_secret" => self.service_integration.backfill_secret,
        "target_url" => "https://api.webhookdb.com/v1/service_integrations/#{self.service_integration.opaque_id}",
        "event" => {"name" => "subscriber.subscriber_activate"},
      },
      logger: self.logger,
    )
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

  def calculate_create_state_machine
    step = Webhookdb::Services::StateMachineStep.new
    step.output = %(
Great! We've created your ConvertKit Subscribers integration.

ConvertKit supports Subscriber webhooks.
You have two options for hooking them up:

A: Create the webhook yourself, so you don't need to provide us an API Secret.
Run this from a shell:

  curl -X POST https://api.convertkit.com/v3/automations/hooks
     -H 'Content-Type: application/json'\\
     -d '{ "api_secret": "<your_secret_api_key>",\\
           "target_url": "#{self._webhook_endpoint}",\\
           "event": { "name": "subscriber.subscriber_activate" } }'
  curl -X POST https://api.convertkit.com/v3/automations/hooks
     -H 'Content-Type: application/json'\\
     -d '{ "api_secret": "<your_secret_api_key>",\\
           "target_url": "#{self._webhook_endpoint}",\\
           "event": { "name": "subscriber.subscriber_unsubscribe" } }'

B: Use WebhookDB to backfill historical data with your API Secret, and when we do this,
we'll also set up webhooks for new data.
To start backfilling historical data, run this from a shell:

  #{self._backfill_command}

Once you have data (you set up the webhooks, or ran the 'backfill' command),
your database will be populated.
#{self._query_help_output}
      )
    return step.completed
  end

  def calculate_backfill_state_machine
    step = Webhookdb::Services::StateMachineStep.new
    if self.service_integration.backfill_secret.blank?
      step.output = %(
In order to backfill ConvertKit Subscribers, we need your API secret.

#{Webhookdb::Convertkit::FIND_API_SECRET_HELP}
      )
      return step.secret_prompt("API Secret").backfill_secret(self.service_integration)
    end
    step.output = %(
Great! We are going to start backfilling your ConvertKit Subscribers.
#{self._query_help_output}
      )
    return step.completed
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

  def _fetch_backfill_page(pagination_token, last_backfilled:)
    pagination_token ||= ["subscribed", 1]
    list_being_iterated, page = pagination_token

    url = "https://api.convertkit.com/v3/subscribers?api_secret=#{self.service_integration.backfill_secret}&page=#{page}&sort_order=desc"
    url += "&sort_field=cancelled_at" if list_being_iterated == "cancelled"

    response = Webhookdb::Http.get(url, logger: self.logger)
    data = response.parsed_response
    current_page = data["page"]
    total_pages = data["total_pages"]
    subs = data["subscribers"]

    if last_backfilled.present?
      earliest_data_created = subs.empty? ? Time.at(0) : subs[-1].fetch("created_at")
      paged_to_already_seen_records = earliest_data_created < last_backfilled

      if paged_to_already_seen_records && list_being_iterated == "subscribed"
        # If we are done backfilling from the 'subscribed' list, we can now iterate cancelled
        return subs, ["cancelled", 1]
      end
      if paged_to_already_seen_records && list_being_iterated == "cancelled"
        # If we are done backfilling from the 'cancelled' list, we are done backfilling
        return subs, nil
      end
    end

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
