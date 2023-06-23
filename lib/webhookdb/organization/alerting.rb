# frozen_string_literal: true

require "appydays/configurable"
require "appydays/loggable"

class Webhookdb::Organization::Alerting
  include Appydays::Configurable

  configurable(:alerting) do
    setting :interval, 24.hours.to_i
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
    self.org.admin_customers.each do |c|
      idemkey = "orgalert-#{signature}-#{c.id}"
      Webhookdb::Idempotency.every(Webhookdb::Organization::Alerting.interval).under_key(idemkey) do
        message_template.dispatch_email(c)
      end
    end
  end
end
