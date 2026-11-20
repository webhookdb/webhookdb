# frozen_string_literal: true

require "appydays/configurable"
require "appydays/loggable"

require "webhookdb/jobs/organization_error_handler_dispatch"

# Alert an organization when errors happen during webhook handling.
# These errors are explicitly managed in the handler code,
# and are usually things like outdated credentials.
# The alerts contain information about the error, and actions to take to fix the problem.
# If an organization has no +Webhookdb::Postgres::ErrorHandler+ registered,
# send an email to org admins instead.
class Webhookdb::Organization::Alerting
  include Appydays::Configurable

  configurable(:alerting) do
    # Only send an alert with a given signature (replicator and error signature)
    # to a given customer this often. Avoid spamming about any single replicator issue.
    setting :interval, 24.hours.to_i
    # Each customer can only receive this many alerts for a given template per day.
    # Avoids spamming a customer when many rows of a replicator have problems.
    setting :max_alerts_per_customer_per_day, 15
    # Timeout when POSTing to a customer-defined URL on errors.
    # Should be relatively short.
    setting :error_handler_timeout, 7
    # How many times should we call an error handler before giving up?
    # Error handlers are often lossy so it's not a big deal to give up.
    setting :error_handler_retries, 5
    # Wait this long before retrying an error handler.
    setting :error_handler_retry_interval, 60
  end

  attr_reader :org

  def initialize(org)
    @org = org
  end

  # Dispatch an alert using the given message template.
  # See +Webhookdb::Organization::Alerting+ for details about how alerts are dispatched.
  # @param message_template [Webhookdb::Message::Template]
  # @param separate_connection [true,false] Only relevant if the organization has no error handlers
  #   and email alerting (+dispatch_alert_default+) is used. If true, send the alert on a separate connection.
  #   See +Webhookdb::Idempotency+. Defaults to true since this is an alert method and we
  #   don't want it to error accidentally, if the code is called from an unexpected situation.
  def dispatch_alert(message_template, separate_connection: true)
    self.validate_template(message_template)
    if self.org.error_handlers.empty?
      self.dispatch_alert_default(message_template, separate_connection:)
      return
    end
    self.org.error_handlers.each do |eh|
      payload = eh.payload_for_template(message_template)
      # It's possible that the template includes caller-provided values including improperly-encoded strings.
      # Sidekiq's strict job args will do a dump/parse to check for valid args,
      # which will potentially fail if valid utf-8 bytes are in a string that's encoded as ascii.
      # Really hard to explain, so see the specs, but there's nothing we can do about invalid content
      # other than not error.
      payload = JSON.parse(JSON.dump(payload))
      Webhookdb::Jobs::OrganizationErrorHandlerDispatch.perform_async(eh.id, payload.as_json)
    end
  end

  private def validate_template(message_template)
    unless message_template.respond_to?(:signature)
      msg = "message template #{message_template.template_name} must define a #signature method, " \
            "which is a unique identity for this error type, used for grouping and idempotency"
      raise Webhookdb::InvalidPrecondition, msg

    end
    unless message_template.respond_to?(:service_integration)
      msg = "message template #{message_template.template_name} must return " \
            "its ServiceIntegration from #service_integration"
      raise Webhookdb::InvalidPrecondition, msg
    end
    return true
  end

  def dispatch_alert_default(message_template, separate_connection:)
    signature = message_template.signature
    max_alerts_per_customer_per_day = Webhookdb::Organization::Alerting.max_alerts_per_customer_per_day
    yesterday = Time.now - 24.hours
    self.org.admin_customers.each do |c|
      idem = Webhookdb::Idempotency.every(Webhookdb::Organization::Alerting.interval)
      idem = idem.using_seperate_connection if separate_connection
      idem.under_key("orgalert-#{signature}-#{c.id}") do
        sent_last_day = Webhookdb::Message::Delivery.
          where(template: message_template.full_template_name, recipient: c).
          where { created_at > yesterday }.
          limit(max_alerts_per_customer_per_day).
          count
        next unless sent_last_day < max_alerts_per_customer_per_day
        message_template.dispatch_email(c)
      end
    end
  end

  # For use in Replicator#on_backfill_error.
  # Alert using the generic backfill error for a 401 (or whatever alert_status),
  # or is a socket error, or potentially some other types of errors we always want to alert about.
  def handle_backfill_error(replicator, be, alert_status: [401])
    e = Webhookdb::Errors.find_cause(be) do |ex|
      next true if ex.is_a?(Webhookdb::Http::Error) && alert_status.include?(ex.status)
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
      replicator.service_integration,
      response_status:,
      response_body:,
      request_url:,
      request_method:,
    )
    self.dispatch_alert(message)
    return true
  end
end
