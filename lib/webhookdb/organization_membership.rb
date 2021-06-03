# frozen_string_literal: true

require "webhookdb/postgres/model"

class Webhookdb::OrganizationMembership < Webhookdb::Postgres::Model(:organization_memberships)
  many_to_one :organization, class: "Webhookdb::Organization"
  many_to_one :customer, class: "Webhookdb::Customer"
  many_to_one :role, class: "Webhookdb::OrganizationRole"

  def customer_email
    return self.customer.email
  end

  def organization_name
    return self.organization.name
  end

  def set_status
    self.status = ""
    self.status = self.role.name unless self.role.nil?
    self.status = "invited" unless self.verified
  end

  def before_create
    self.set_status
    super
  end

  def before_save
    self.set_status
    super
  end
end