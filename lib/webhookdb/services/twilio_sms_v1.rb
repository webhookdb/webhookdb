# frozen_string_literal: true

class Webhookdb::Services::TwilioSmsV1 < Webhookdb::Services::Base
  include Appydays::Loggable

  # @return [Webhookdb::Services::Descriptor]
  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "twilio_sms_v1",
      ctor: ->(sint) { Webhookdb::Services::TwilioSmsV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "Twilio SMS Message",
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

  def calculate_create_state_machine
    return self.calculate_backfill_state_machine
  end

  def calculate_backfill_state_machine
    step = Webhookdb::Services::StateMachineStep.new
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
      self.service_integration.service_instance.clear_backfill_information
      step.output = result.message
      return step.secret_prompt("API Key").backfill_key(self.service_integration)
    end

    step.output = %(Great! We are going to start backfilling your Twilio SMS information, and will keep it updated.
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
    return Webhookdb::Services::Column.new(:twilio_id, TEXT)
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:date_created, TIMESTAMP, index: true),
      Webhookdb::Services::Column.new(:date_sent, TIMESTAMP, index: true),
      Webhookdb::Services::Column.new(:date_updated, TIMESTAMP, index: true),
      Webhookdb::Services::Column.new(:direction, TEXT),
      Webhookdb::Services::Column.new(:from, TEXT, index: true),
      Webhookdb::Services::Column.new(:status, TEXT),
      Webhookdb::Services::Column.new(:to, TEXT, index: true),
    ]
  end

  def _timestamp_column_name
    return :date_updated
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:date_updated] < Sequel[:excluded][:date_updated]
  end

  def _prepare_for_insert(body, **_kwargs)
    return {
      twilio_id: body.fetch("sid"),
      date_created: Time.parse(body.fetch("date_created")),
      date_sent: Time.parse(body.fetch("date_sent")),
      date_updated: Time.parse(body.fetch("date_updated")),
      direction: body.fetch("direction"),
      from: body.fetch("from"),
      status: body.fetch("status"),
      to: body.fetch("to"),
    }
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
