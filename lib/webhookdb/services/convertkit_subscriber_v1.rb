# frozen_string_literal: true

require "time"
require "webhookdb/convertkit"
require "webhookdb/services/convertkit_v1_mixin"

class Webhookdb::Services::ConvertkitSubscriberV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::ConvertkitV1Mixin

  # @return [Webhookdb::Services::Descriptor]
  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "convertkit_subscriber_v1",
      ctor: ->(sint) { Webhookdb::Services::ConvertkitSubscriberV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "ConvertKit Subscriber",
    )
  end

  def process_state_change(field, value)
    step = super
    self._create_webhooks if field == "backfill_secret"
    return step
  end

  def _create_webhooks
    # ConvertKit has made several other webhooks available for the subscriber object, but they all have required
    # parameters that are pks of other objects that webhookdb knows nothing about.

    # first verify that the webhooks don't exist
    url = "https://api.convertkit.com/v3/automations/hooks?api_secret=#{self.service_integration.backfill_secret}"
    response = Webhookdb::Http.get(url, logger: self.logger)
    # the data returned here is a list of the existing webhooks
    data = response.parsed_response

    # does the "subscriber.subscriber_activate" exist? if not, create it
    # rubocop:disable Style/GuardClause
    if data.present?
      sub_activate_webhook = data.find do |obj|
        obj.dig("rule", "event", "name") == "subscriber_activate"
      end
    end
    unless sub_activate_webhook.present?
      Webhookdb::Http.post(
        "https://api.convertkit.com/v3/automations/hooks",
        {
          "api_secret" => self.service_integration.backfill_secret,
          "target_url" => self.service_integration.unauthed_webhook_path,
          "event" => {"name" => "subscriber.subscriber_activate"},
        },
        logger: self.logger,
      )
      end

    # does the "subscriber.subscriber_activate" exist? if not, create it
    if data.present?
      sub_unsubscribe_webhook = data.find do |obj|
        obj.dig("rule", "event", "name") == "subscriber_activate"
      end
    end
    unless sub_unsubscribe_webhook.present?
      Webhookdb::Http.post(
        "https://api.convertkit.com/v3/automations/hooks",
        {
          "api_secret" => self.service_integration.backfill_secret,
          "target_url" => self.service_integration.unauthed_webhook_path,
          "event" => {"name" => "subscriber.subscriber_unsubscribe"},
        },
        logger: self.logger,
      )
    end
    # rubocop:enable Style/GuardClause
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

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:created_at, TIMESTAMP, index: true),
      Webhookdb::Services::Column.new(:canceled_at, TIMESTAMP, index: true),
      Webhookdb::Services::Column.new(:email_address, TEXT, index: true),
      Webhookdb::Services::Column.new(:first_name, TEXT),
      Webhookdb::Services::Column.new(:last_name, TEXT),
      Webhookdb::Services::Column.new(:state, TEXT),
    ]
  end

  def _prepare_for_insert(body, **_kwargs)
    object_of_interest = body["subscriber"].present? ? body["subscriber"] : body
    state = object_of_interest["state"]
    return {
      convertkit_id: object_of_interest.fetch("id"),
      created_at: object_of_interest.fetch("created_at"),
      email_address: object_of_interest.fetch("email_address"),
      first_name: object_of_interest.fetch("first_name"),
      last_name: object_of_interest.dig("fields", "last_name"),
      state:,
      # Subscribers do not store a cancelation time (nor an updated at time),
      # so we derive and store it based on their state.
      # When they become inactive state, we set canceled_at,
      # and clear it when they are not active.
      # See upsert_update_expr for the details.
      canceled_at: state == "active" ? nil : Time.now,
    }
  end

  def _update_where_expr
    return Sequel[self.table_sym][:data] !~ Sequel[:excluded][:data]
  end

  def _upsert_update_expr(inserting, **_kwargs)
    state = inserting.fetch(:state)
    # If the state is active, we want to use canceled_at:nil unconditionally.
    return inserting if state == "active"
    # If it's inactive, we only want to update canceled_at if it's not already set
    # (coalesce the existing row's canceled_at with the 'time.now' we are passing in).
    update = inserting.dup
    update[:canceled_at] = Sequel.function(
      :coalesce, Sequel[self.table_sym][:canceled_at], Sequel[:excluded][:canceled_at],
    )
    return update
  end

  def _fetch_backfill_page(pagination_token, last_backfilled:)
    pagination_token ||= ["subscribed", 1]
    list_being_iterated, page = pagination_token

    url = "https://api.convertkit.com/v3/subscribers?api_secret=#{self.service_integration.backfill_secret}&page=#{page}&sort_order=desc"
    url += "&updated_from=#{last_backfilled.strftime('%FT%TZ')}" if last_backfilled.present?
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
