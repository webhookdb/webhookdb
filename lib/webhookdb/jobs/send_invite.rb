# frozen_string_literal: true

require "webhookdb/async/job"
require "webhookdb/messages/invite"

class Webhookdb::Jobs::SendInvite
  extend Webhookdb::Async::Job

  on "webhookdb.organizationmembership.invite"

  def _perform(event)
    m = self.lookup_model(Webhookdb::OrganizationMembership, event)
    self.set_job_tags(membership_id: m.id, organization: m.organization.key, customer: m.customer.email)
    Webhookdb::Messages::Invite.new(m).dispatch(m.customer)
  end
end
