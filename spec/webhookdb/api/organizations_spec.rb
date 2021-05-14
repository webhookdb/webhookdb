# frozen_string_literal: true

require "webhookdb/api/organizations"

RSpec.describe Webhookdb::API::Organizations, :db do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }

  let!(:customer) { Webhookdb::Fixtures.customer.create }
  let!(:org) { Webhookdb::Fixtures.organization.create }
  let!(:membership) { org.add_membership(customer: customer, verified: true) }
  let!(:admin_role) { Webhookdb::OrganizationRole.create(name: "admin") }

  before(:each) do
    login_as(customer)
  end

  # GET

  describe "GET /v1/organizations" do
    it "returns all organizations associated with customer" do
      other_org_in = Webhookdb::Fixtures.organization.with_member(customer).create
      _org_not_in = Webhookdb::Fixtures.organization.create

      get "/v1/organizations"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(items: have_same_ids_as(org, other_org_in))
    end

    it "returns a message if customer has no organizations" do
      membership.destroy

      get "/v1/organizations"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        message: "You aren't affiliated with any organizations yet.",
      )
    end
  end

  describe "GET /v1/organizations/:organization_id/members" do
    it "returns all customers associated with organization" do
      extra_customers = Array.new(3) { Webhookdb::Fixtures.customer.create }
      extra_customers.each { |c| org.add_membership(customer: c) }

      get "/v1/organizations/#{org.id}/members"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(items: have_length(4))
    end

    it "403s if the customer is not a member" do
      membership.destroy

      get "/v1/organizations/#{org.id}/members"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "You don't have permissions with that organization."),
      )
    end
  end

  describe "GET v1/organizations/:organization_id/service_integrations" do
    it "returns all service integrations associated with organization" do
      integrations = Array.new(2) { Webhookdb::Fixtures.service_integration.create }
      _extra_integrations = Webhookdb::Fixtures.service_integration.create

      integrations.each { |i| org.add_service_integration(i) }
      get "/v1/organizations/#{org.id}/service_integrations"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(items: have_same_ids_as(integrations))
    end

    it "returns a message if org has no service integrations" do
      get "/v1/organizations/#{org.id}/service_integrations"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(message: "Organization doesn't have any integrations yet.")
    end
  end

  # POST

  describe "POST /v1/organizations/:organization_id/invite" do
    it "creates invited customer if no customer with that email exists" do
      nonexistent_customer = Webhookdb::Customer[email: "bugsbunny@aol.com"]
      expect(nonexistent_customer).to be_nil

      post "/v1/organizations/#{org.id}/invite", email: "bugsbunny@aol.com"

      invited_customer = Webhookdb::Customer[email: "bugsbunny@aol.com"]
      expect(invited_customer).to_not be_nil
    end

    it "creates correct organization membership for the invited customer" do
      post "/v1/organizations/#{org.id}/invite", email: "daffyduck@hotmail.com"

      invited_customer = Webhookdb::Customer[email: "daffyduck@hotmail.com"]
      membership = Webhookdb::OrganizationMembership[customer_id: invited_customer.id, organization_id: org.id]

      expect(membership).to_not be_nil
      expect(membership.verified).to eq(false)
      expect(membership.status).to eq("invited")
      expect(membership.invitation_code).to include("join-")
    end

    it "returns correct status and response when successful" do
      post "/v1/organizations/#{org.id}/invite", email: "elmerfudd@comcast.net"

      invited_customer = Webhookdb::Customer[email: "elmerfudd@comcast.net"]
      membership = Webhookdb::OrganizationMembership[customer_id: invited_customer.id, organization_id: org.id]

      expect(last_response).to have_status(201)
      expect(last_response).to have_json_body.
        that_includes(message: include("An invitation has been sent to elmerfudd@comcast.net."))
    end

    it "returns 400 if customer is already a part of the organization" do
      invited_customer = Webhookdb::Fixtures.customer.create(email: "porkypig@gmail.com")
      org.add_membership(customer: invited_customer)

      post "/v1/organizations/#{org.id}/invite", email: "porkypig@gmail.com"

      expect(last_response).to have_status(400)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "That person is already a member of the organization."),
      )
    end
  end

  describe "POST /v1/organizations/:organization_id/remove" do
    it "fails if request customer doesn't have admin privileges" do
      test_customer = Webhookdb::Fixtures.customer.create(email: "yosemitesam@gmail.com")
      org.add_membership(customer: test_customer)

      post "/v1/organizations/#{org.id}/remove", email: "yosemitesam@gmail.com"

      expect(last_response).to have_status(400)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "Permission denied: You don't have admin privileges with #{org.name}."),
      )
    end

    it "fails if customer is not part of the organization" do
      customer.memberships_dataset.update(role_id: admin_role.id)
      test_customer = Webhookdb::Fixtures.customer.create(email: "tweetybird@yahoo.com")
      expect(test_customer.memberships).to eq([])

      post "/v1/organizations/#{org.id}/remove", email: "tweetybird@yahoo.com"

      expect(last_response).to have_status(400)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "That user is not a member of #{org.name}."),
      )
    end

    it "removes user from organization and returns correct message" do
      customer.memberships_dataset.update(role_id: admin_role.id)

      test_customer = Webhookdb::Fixtures.customer.create(email: "roadrunner@wb.com")
      org.add_membership(customer: test_customer)

      post "/v1/organizations/#{org.id}/remove", email: "roadrunner@wb.com"

      test_customer_membership = org.memberships_dataset[customer: test_customer]

      expect(test_customer_membership).to be_nil
      expect(last_response).to have_status(201)
      expect(last_response).to have_json_body.that_includes(
        message: "roadrunner@wb.com is no longer a part of the Lithic Technology organization.",
      )
    end
  end

  describe "POST /v1/organizations/:organization_id/change_roles" do
    it "changes the roles of customers and returns correct response" do
      customer.memberships_dataset.update(role_id: admin_role.id)

      membership_a = org.add_membership(customer: Webhookdb::Fixtures.customer.create(email: "pepelepew@yahoo.com"))
      membership_b = org.add_membership(customer: Webhookdb::Fixtures.customer.create(email: "marvinthe@martian.com"))

      post "v1/organizations/#{org.id}/change_roles", emails: ["pepelepew@yahoo.com", "marvinthe@martian.com"],
                                                      role_name: "troublemaker"

      troublemaker_memberships = org.memberships_dataset.where(
        role_id: Webhookdb::OrganizationRole[name: "troublemaker"].id,
      )
      expect(troublemaker_memberships).to have_same_ids_as([membership_a, membership_b])

      expect(last_response).to have_status(201)
      expect(last_response).to have_json_body.that_includes(
        include(message: "Success! These users have now been assigned the role of troublemaker in #{org.name}."),
      )
    end

    it "errors if the customers are not a part of the organization" do
      customer.memberships_dataset.update(role_id: admin_role.id)
      Webhookdb::Fixtures.customer.create(email: "sylvester@yahoo.com")

      post "/v1/organizations/#{org.id}/change_roles", emails: ["sylvester@yahoo.com"], role_name: "cat"

      expect(last_response).to have_status(400)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "Those emails do not belong to members of #{org.name}."),
      )
    end

    it "fails if request customer doesn't have admin privileges" do
      org.add_membership(customer: Webhookdb::Fixtures.customer.create(email: "foghornleghorn@gmail.com"))

      post "/v1/organizations/#{org.id}/change_roles", emails: ["foghornleghorn@gmail.com"],
                                                       role_name: "twilio specialist"

      expect(last_response).to have_status(400)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "Permission denied: You don't have admin privileges with #{org.name}."),
      )
    end
  end

  describe "POST v1/organizations/create" do
    it "creates new organization and creates membership for current customer" do
      post "v1/organizations/create", name: "Acme Corporation"

      new_org = Webhookdb::Organization[name: "Acme Corporation"]
      expect(new_org).to_not be_nil
      expect(new_org.key).to eq("acme_corporation")

      expect(new_org.memberships_dataset.where(customer: customer).all).to have_length(1)
    end

    it "returns correct message" do
      post "v1/organizations/create", name: "Acme Corporation"

      expect(last_response).to have_status(201)
      expect(last_response).to have_json_body.that_includes(
        message: include("Your organization identifier is: acme_corporation"),
      )
    end

    it "errors if organization key is not unique" do
      Webhookdb::Fixtures.organization(name: "Acme Corporation").create

      post "v1/organizations/create", name: "Acme Corporation"

      expect(last_response).to have_status(400)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "An organization with that name already exists."),
      )
    end
  end

  describe "POST v1/organizations/join" do
    it "verifies organization membership and returns correct response" do
      org.add_membership(customer: customer, invitation_code: "join-abcxyz")

      post "v1/organizations/join", invitation_code: "join-abcxyz"

      expect(last_response).to have_status(201)
      expect(last_response).to have_json_body.
        that_includes(message: "Congratulations! You are now a member of #{org.name}.")
    end

    it "returns 400 if invitation code is invalid" do
      post "v1/organizations/join", invitation_code: "join-abcxyz"

      expect(last_response).to have_status(400)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "Looks like that invite code is invalid. Please try again."),
      )
    end
  end
end
