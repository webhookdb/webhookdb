# frozen_string_literal: true

require "webhookdb/async/job"
require "webhookdb/messages/invite"

class Webhookdb::Jobs::SendInvite
  extend Webhookdb::Async::Job

  on "webhookdb.organizationmembership.invite"

  def _perform(event)
    membership = self.lookup_model(Webhookdb::OrganizationMembership, event)
    Webhookdb::Messages::Invite.new(membership).dispatch(membership.customer)
  end
end
