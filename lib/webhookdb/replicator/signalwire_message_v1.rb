# frozen_string_literal: true

require "webhookdb/errors"
require "webhookdb/signalwire"
require "webhookdb/messages/error_generic_backfill"

class Webhookdb::Replicator::SignalwireMessageV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "signalwire_message_v1",
      ctor: ->(sint) { Webhookdb::Replicator::SignalwireMessageV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "SignalWire Message",
      supports_backfill: true,
      api_docs_url: "https://developer.signalwire.com/compatibility-api/rest/list-all-messages",
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

  def process_state_change(field, value, attr: nil)
    if field == "api_url" && value.include?(".")
      value = "https://" + value unless value.include?("://")
      u = URI(value)
      h = u.host.gsub(/\.signalwire\.com$/, "")
      value = h
    end
    return super
  end

  def calculate_backfill_state_machine
    step = Webhookdb::Replicator::StateMachineStep.new
    unless self.service_integration.api_url.present?
      step.output = %(Let's finish setting up your SignalWire Messaging (SMS) integration.

Rather than using your phone number's webhooks (of which each number can have only one),
we poll SignalWire for changes, and will also backfill historical messages.

To do this, we need your Space URL, Project ID, and an API Token.

First enter your Space URL. You can see this on your SignalWire dashboard.
It's the part of your dashboard URL before '.signalwire.com'.)
      return step.prompting("Space URL").api_url(self.service_integration)
    end

    unless self.service_integration.backfill_key.present?
      step.output = %(You can get your Project ID from the 'API' section of your SignalWire dashboard.

Go to https://#{self.service_integration.api_url}.signalwire.com/credentials and copy your Project ID.)
      return step.prompting("Project ID").backfill_key(self.service_integration)
    end

    unless self.service_integration.backfill_secret.present?
      step.needs_input = true
      step.output = %(Let's create or reuse an API token.

Go to https://#{self.service_integration.api_url}.signalwire.com/credentials
and press the 'New' button.
Name the token something like 'WebhookDB'.
Under Scopes, ensure the 'Messaging' checkbox is checked.
Then press 'Save'.

Press 'Show' next to the newly-created API token, and copy it.)
      return step.secret_prompt("API Token").backfill_secret(self.service_integration)
    end

    unless self.verify_backfill_credentials.verified?
      self.service_integration.replicator.clear_backfill_information
      return self.calculate_backfill_state_machine.
          with_output("Something is wrong with your configuration. Please look over the instructions and try again.")
    end

    step.output = %(We are going to start replicating your SignalWire Messages, and will keep it updated.
#{self._query_help_output}
      )
    return step.completed
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:signalwire_id, TEXT, data_key: "sid")
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

  def signalwire_http_request(method, url, **kw)
    return Webhookdb::Signalwire.http_request(
      method,
      url,
      space_url: self.service_integration.api_url,
      project_id: self.service_integration.backfill_key,
      api_key: self.service_integration.backfill_secret,
      logger: self.logger,
      **kw,
    )
  end

  def _fetch_backfill_page(pagination_token, last_backfilled:)
    urltail = pagination_token
    if pagination_token.blank?
      # We need to handle positive and negative UTC offset running locally (non-UTC).
      # Using UTC + 1 day would give 'today' in some cases, we always want 'tomorrow the day after'.
      date_send_max = (Time.now.utc + 2.days).to_date
      urltail = "/api/laml/2010-04-01/Accounts/#{self.service_integration.backfill_key}/Messages.json" \
                "?PageSize=100&DateSend%3C=#{date_send_max}"
    end
    data = self.signalwire_http_request(:get, urltail)
    messages = data["messages"]

    if last_backfilled.present?
      earliest_data_created = messages.empty? ? Time.at(0) : messages[-1].fetch("date_created")
      paged_to_already_seen_records = earliest_data_created < last_backfilled

      return messages, nil if paged_to_already_seen_records
    end

    return messages, data["next_page_uri"]
  end

  def on_backfill_error(be)
    e = Webhookdb::Errors.find_cause(be) do |ex|
      next true if ex.is_a?(Webhookdb::Http::Error) && ex.status == 401
      next true if ex.is_a?(::SocketError)
    end
    return unless e
    if e.is_a?(::SocketError)
      response_status = 0
      response_body = e.message
      request_url = "<unknown>"
      request_method = "<unknown>"
    else
      response_status = e.status
      response_body = e.body
      request_url = e.uri.to_s
      request_method = e.http_method
    end
    message = Webhookdb::Messages::ErrorGenericBackfill.new(
      self.service_integration,
      response_status:,
      response_body:,
      request_url:,
      request_method:,
    )
    self.service_integration.organization.alerting.dispatch_alert(message)
    return true
  end
end
