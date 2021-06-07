# frozen_string_literal: true

require "httparty"

class Webhookdb::Services::TwilioSmsV1 < Webhookdb::Services::Base
  include Appydays::Loggable

  def webhook_response(request)
    auth = request.get_header("Authorization")
    if auth.nil? || !auth.match(/^Basic /)
      return [401, {"Content-Type" => "text/plain", "WWW-Authenticate" => 'Basic realm="Webhookdb"'}, ""]
    end
    user_and_pass = Base64.decode64(auth.gsub(/^Basic /, ""))
    return [401, {"Content-Type" => "text/plain"}, ""] if user_and_pass != self.service_integration.webhook_secret
    return [202, {"Content-Type" => "text/xml"}, "<Response></Response>"]
  end

  # rubocop:disable Lint/DuplicateBranch
  def process_state_change(field, value)
    self.service_integration.db.transaction do
      self.service_integration.send("#{field}=", value)
      self.service_integration.save_changes
      case field
        when "backfill_key"
          return self.calculate_backfill_state_machine(self.service_integration.organization)
        when "backfill_secret"
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
    step.needs_input = false
    step.output = %(
Great! We've created your Twilio SMS Service Integration.
You can query the database through your organization's Postgres connection string:

#{organization.readonly_connection_url}

You can also run a query through the CLI:

webhookdb db sql "SELECT * FROM twilio_sms_v1"

If you want to populate the Twilio SMS database, you'll need to set up backfill functionality.
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
In order to backfill Twilio SMS, we need your Account SID and Auth Token.
Both of these values should be visible from the homepage of your Twilio admin Dashboard.
      )
      step.prompt = "Paste or type your Account SID here:"
      step.prompt_is_secret = true
      step.post_to_url = "/v1/service_integrations/#{self.service_integration.opaque_id}/transition/backfill_key"
      step.complete = false
      return step
    end

    unless self.service_integration.backfill_secret.present?
      step.needs_input = true
      step.prompt = "Paste or type your Auth Token here:"
      step.prompt_is_secret = true
      step.post_to_url = "/v1/service_integrations/#{self.service_integration.opaque_id}/transition/backfill_secret"
      step.complete = false
      return step
    end

    step.needs_input = false
    step.output = %(
Great! We are going to start backfilling your Twilio SMS information.
Twilio allows us to backfill your entire SMS history,
so you're in good shape.

You can query the database through your organization's Postgres connection string:

#{organization.readonly_connection_url}

You can also run a query through the CLI:

webhookdb db sql "SELECT * FROM twilio_sms_v1"
      )
    step.complete = true
    return step
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:twilio_id, "text")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:date_created, "timestamptz"),
      Webhookdb::Services::Column.new(:date_sent, "timestamptz"),
      Webhookdb::Services::Column.new(:date_updated, "timestamptz"),
      Webhookdb::Services::Column.new(:direction, "text"),
      Webhookdb::Services::Column.new(:from, "text"),
      Webhookdb::Services::Column.new(:status, "text"),
      Webhookdb::Services::Column.new(:to, "text"),
    ]
  end

  def _update_where_expr
    return Sequel[self.table_sym][:date_updated] < Sequel[:excluded][:date_updated]
  end

  def _prepare_for_insert(body)
    return {
      twilio_id: body["sid"],
      date_created: Time.parse(body["date_created"]),
      date_sent: Time.parse(body["date_sent"]),
      date_updated: Time.parse(body["date_updated"]),
      direction: body["direction"],
      from: body["from"],
      status: body["status"],
      to: body["to"],
    }
  end

  def _fetch_backfill_page(pagination_token)
    unless (url = pagination_token)
      date_send_max = Date.tomorrow
      url = "/2010-04-01/Accounts/#{self.service_integration.backfill_key}/Messages.json" \
        "?PageSize=100&DateSend%3C=#{date_send_max}"
    end
    url = "https://api.twilio.com" + url
    response = HTTParty.get(
      url,
      basic_auth: {username: self.service_integration.backfill_key,
                   password: self.service_integration.backfill_secret,},
      logger: self.logger,
    )
    raise response if response.code >= 300
    data = response.parsed_response
    return data["messages"], data["next_page_uri"]
  end
end
