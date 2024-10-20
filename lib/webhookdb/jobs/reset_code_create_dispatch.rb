# frozen_string_literal: true

require "webhookdb/async/job"
require "webhookdb/messages/verification"

class Webhookdb::Jobs::ResetCodeCreateDispatch
  extend Webhookdb::Async::Job

  on "webhookdb.customer.resetcode.created"

  def _perform(event)
    code = self.lookup_model(Webhookdb::Customer::ResetCode, event)
    self.set_job_tags(code_id: code.id, customer: code.customer.email, transport: code.transport)
    Webhookdb::Idempotency.once_ever.under_key("reset-code-#{code.customer_id}-#{code.id}") do
      msg = Webhookdb::Messages::Verification.new(code)
      case code.transport
        when "email"
          msg.dispatch_email(code.customer)
      end
    end
  end
end
