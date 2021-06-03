# frozen_string_literal: true

require "webhookdb/message/template"

class Webhookdb::Messages::Invite < Webhookdb::Message::Template
  def self.fixtured(recipient)
    org = Webhookdb::Fixtures.organization.with_member(recipient).create
    membership = org.memberships[0]
    return self.new(membership)
  end

  def initialize(membership)
    @membership = membership
    super()
  end

  def liquid_drops
    return super.merge(
      organization_name: @membership.organization_name,
      invite_code: @membership.invitation_code,
    )
  end
end
