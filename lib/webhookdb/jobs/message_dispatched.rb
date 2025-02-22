# frozen_string_literal: true

require "webhookdb/async/job"

class Webhookdb::Jobs::MessageDispatched
  extend Webhookdb::Async::Job

  on "webhookdb.message.delivery.dispatched"

  def _perform(event)
    delivery = self.lookup_model(Webhookdb::Message::Delivery, event)
    self.set_job_tags(delivery_id: delivery.id, to: delivery.to)
    Webhookdb::Idempotency.once_ever.under_key("message-dispatched-#{delivery.id}") do
      delivery.send!
    end
  end
end
