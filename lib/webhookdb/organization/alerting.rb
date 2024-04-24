# frozen_string_literal: true

require "appydays/configurable"
require "appydays/loggable"

class Webhookdb::Organization::Alerting
  include Appydays::Configurable

  configurable(:alerting) do
    # Only send an alert with a given signature (replicator and error signature)
    # to a given customer this often. Avoid spamming about any single replicator issue.
    setting :interval, 24.hours.to_i
    # Each customer can only receive this many alerts for a given template per day.
    # Avoids spamming a customer when many rows of a replicator have problems.
    setting :max_alerts_per_customer_per_day, 15
  end

  attr_reader :org

  def initialize(org)
    @org = org
  end

  # Dispatch the message template to administrators of the org.
  # @param message_template [Webhookdb::Message::Template]
  def dispatch_alert(message_template)
    unless message_template.respond_to?(:signature)
      raise Webhookdb::InvalidPrecondition,
            "message template #{message_template.template_name} must define a #signature method, " \
            "which is a unique identity for this error type, used for grouping and idempotency"
    end
    signature = message_template.signature
    max_alerts_per_customer_per_day = Webhookdb::Organization::Alerting.max_alerts_per_customer_per_day
    yesterday = Time.now - 24.hours
    self.org.admin_customers.each do |c|
      idemkey = "orgalert-#{signature}-#{c.id}"
      Webhookdb::Idempotency.every(Webhookdb::Organization::Alerting.interval).under_key(idemkey) do
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
end
