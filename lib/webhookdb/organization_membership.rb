# frozen_string_literal: true

require "webhookdb/postgres/model"

class Webhookdb::OrganizationMembership < Webhookdb::Postgres::Model(:organization_memberships)
  VALID_ROLE_NAMES = ["admin", "member"].freeze

  many_to_one :organization, class: "Webhookdb::Organization"
  many_to_one :customer, class: "Webhookdb::Customer"
  many_to_one :membership_role, class: "Webhookdb::Role"

  def verified?
    return self.verified
  end

  def default?
    return self.is_default
  end

  def customer_email
    return self.customer.email
  end

  def organization_name
    return self.organization.name
  end

  def status
    return "invited" unless self.verified
    self.membership_role.name
  end
end

# Table: organization_memberships
# --------------------------------------------------------------------------------------------------
# Columns:
#  id                 | integer | PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY
#  customer_id        | integer | NOT NULL
#  organization_id    | integer | NOT NULL
#  verified           | boolean | NOT NULL DEFAULT true
#  invitation_code    | text    |
#  status             | text    |
#  membership_role_id | integer |
# Indexes:
#  organization_memberships_pkey | PRIMARY KEY btree (id)
# Foreign key constraints:
#  organization_memberships_customer_id_fkey        | (customer_id) REFERENCES customers(id)
#  organization_memberships_membership_role_id_fkey | (membership_role_id) REFERENCES roles(id)
#  organization_memberships_organization_id_fkey    | (organization_id) REFERENCES organizations(id)
# --------------------------------------------------------------------------------------------------
