# frozen_string_literal: true

require "webhookdb/async/job"

class Webhookdb::Async::MessageDispatched
  extend Webhookdb::Async::Job

  on "webhookdb.message.delivery.dispatched"

  def _perform(event)
    delivery = self.lookup_model(Webhookdb::Message::Delivery, event)
    Webhookdb::Idempotency.once_ever.under_key("message-dispatched-#{delivery.id}") do
      delivery.send!
    end
  end
end
