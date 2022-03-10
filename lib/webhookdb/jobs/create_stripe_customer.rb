# frozen_string_literal: true

require "webhookdb/async/job"
require "stripe"
require "webhookdb/stripe"

class Webhookdb::Jobs::CreateStripeCustomer
  extend Webhookdb::Async::Job

  on "webhookdb.organization.created"

  def _perform(event)
    org = self.lookup_model(Webhookdb::Organization, event)
    org.register_in_stripe
  end
end
