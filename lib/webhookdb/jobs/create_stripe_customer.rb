# frozen_string_literal: true

require "webhookdb/async/job"
require "stripe"
require "webhookdb/stripe"

class Webhookdb::Jobs::CreateStripeCustomer
  extend Webhookdb::Async::Job

  on "webhookdb.organization.created"

  def _perform(event)
    Stripe.api_key = Webhookdb::Stripe.api_key
    org = self.lookup_model(Webhookdb::Organization, event)
    stripe_customer = Stripe::Customer.create({
                                                name: org.name,
                                                email: org.billing_email,
                                                metadata: {
                                                  org_id: org.id,
                                                },
                                              })
    # Should this be in a db transaction ?
    org.stripe_customer_id = stripe_customer.id
    org.save_changes
  end
end
