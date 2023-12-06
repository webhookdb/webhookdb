# frozen_string_literal: true

require "webhookdb/twilio"

class Webhookdb::Replicator::TwilioSmsV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "twilio_sms_v1",
      ctor: ->(sint) { Webhookdb::Replicator::TwilioSmsV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "Twilio SMS Message",
      supports_backfill: true,
    )
  end

  def _webhook_response(request)
    auth = request.get_header("Authorization")
    if auth.nil? || !auth.match(/^Basic /)
      return Webhookdb::WebhookResponse.new(
        status: 401,
        body: "",
        reason: "challenge",
        headers: {"Content-Type" => "text/plain", "WWW-Authenticate" => 'Basic realm="Webhookdb"'},
      )
    end
    user_and_pass = Base64.decode64(auth.gsub(/^Basic /, ""))
    if user_and_pass != self.service_integration.webhook_secret
      return Webhookdb::WebhookResponse.new(
        status: 401,
        body: "",
        reason: "invalid",
        headers: {"Content-Type" => "text/plain"},
      )
    end
    return Webhookdb::WebhookResponse.new(
      status: 202,
      headers: {"Content-Type" => "text/xml"},
      body: "<Response></Response>",
    )
  end

  def calculate_backfill_state_machine
    step = Webhookdb::Replicator::StateMachineStep.new
    unless self.service_integration.backfill_key.present?
      step.needs_input = true
      step.output = %(Great! We've created your Twilio SMS integration.

Rather than using your Twilio Webhooks (of which each number can have only one),
we poll Twilio for changes, and will also backfill historical SMS.

To do this, we need your Account SID and Auth Token.
Both of these values should be visible from the homepage of your Twilio admin Dashboard.
      )
      return step.secret_prompt("Account SID").backfill_key(self.service_integration)
    end

    unless self.service_integration.backfill_secret.present?
      return step.secret_prompt("Auth Token").backfill_secret(self.service_integration)
    end

    unless (result = self.verify_backfill_credentials).verified
      self.service_integration.replicator.clear_backfill_information
      step.output = result.message
      return step.secret_prompt("API Key").backfill_key(self.service_integration)
    end

    step.output = %(We are going to start replicating your Twilio SMS information, and will keep it updated.
#{self._query_help_output}
      )
    return step.completed
  end

  def _verify_backfill_401_err_msg
    return "It looks like that API Key is invalid. Please reenter the API Key you just created:"
  end

  def _verify_backfill_err_msg
    return "An error occurred. Please reenter the API Key you just created:"
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:twilio_id, TEXT, data_key: "sid")
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(
        :date_created,
        TIMESTAMP,
        index: true,
        converter: Webhookdb::Replicator::Column::CONV_PARSE_TIME,
      ),
      Webhookdb::Replicator::Column.new(
        :date_sent,
        TIMESTAMP,
        index: true,
        converter: Webhookdb::Replicator::Column::CONV_PARSE_TIME,
      ),
      Webhookdb::Replicator::Column.new(
        :date_updated,
        TIMESTAMP,
        index: true,
        converter: Webhookdb::Replicator::Column::CONV_PARSE_TIME,
      ),
      Webhookdb::Replicator::Column.new(:direction, TEXT),
      Webhookdb::Replicator::Column.new(:from, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:status, TEXT),
      Webhookdb::Replicator::Column.new(:to, TEXT, index: true),
    ]
  end

  def _timestamp_column_name
    return :date_updated
  end

  def _resource_and_event(request)
    return request.body, nil
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:date_updated] < Sequel[:excluded][:date_updated]
  end

  def _fetch_backfill_page(pagination_token, last_backfilled:)
    url = "https://api.twilio.com"
    if pagination_token.blank?
      date_send_max = Date.tomorrow
      url += "/2010-04-01/Accounts/#{self.service_integration.backfill_key}/Messages.json" \
             "?PageSize=100&DateSend%3C=#{date_send_max}"
    else
      url += pagination_token
    end
    response = Webhookdb::Http.get(
      url,
      basic_auth: {username: self.service_integration.backfill_key,
                   password: self.service_integration.backfill_secret,},
      logger: self.logger,
      timeout: Webhookdb::Twilio.http_timeout,
    )
    data = response.parsed_response
    messages = data["messages"]

    if last_backfilled.present?
      earliest_data_created = messages.empty? ? Time.at(0) : messages[-1].fetch("date_created")
      paged_to_already_seen_records = earliest_data_created < last_backfilled

      return messages, nil if paged_to_already_seen_records
    end

    return messages, data["next_page_uri"]
  end
end
