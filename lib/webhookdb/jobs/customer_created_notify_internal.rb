# frozen_string_literal: true

require "webhookdb/async/job"

class Webhookdb::Jobs::CustomerCreatedNotifyInternal
  extend Webhookdb::Async::Job

  on "webhookdb.customer.created"

  def _perform(event)
    customer = self.lookup_model(Webhookdb::Customer, event)
    Webhookdb::DeveloperAlert.new(
      subsystem: "Customer Created",
      emoji: ":hook:",
      fallback: "New customer created: #{customer.inspect}",
      fields: [
        {title: "Id", value: customer.id, short: true},
        {title: "Email", value: customer.email, short: true},
      ],
    ).emit
  end
end
