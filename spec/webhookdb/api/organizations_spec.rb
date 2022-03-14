# frozen_string_literal: true

require "webhookdb/api/organizations"
require "webhookdb/async"

RSpec.describe Webhookdb::API::Organizations, :async, :db do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }

  let!(:customer) { Webhookdb::Fixtures.customer.create }
  let!(:org) { Webhookdb::Fixtures.organization.create }
  let!(:membership) { org.add_membership(customer:, verified: true) }
  let!(:admin_role) { Webhookdb::Role.create(name: "admin") }
  let!(:member_role) { Webhookdb::Role.create(name: "member") }

  before(:all) do
    Webhookdb::Async.require_jobs
  end

  before(:each) do
    login_as(customer)
  end

  describe "GET /v1/organizations/:org_identifier" do
    it "returns organization associated with identifier" do
      get "/v1/organizations/#{org.key}"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(id: org.id)
    end

    it "403s if the org does not exist or customer doesn't have permissions" do
      get "/v1/organizations/fake_org"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "There is no organization with that identifier."),
      )
    end
  end

  describe "GET /v1/organizations/:org_identifier/members" do
    it "returns all customers associated with organization" do
      extra_customers = Array.new(3) { Webhookdb::Fixtures.customer.create }
      extra_customers.each { |c| org.add_membership(customer: c) }

      get "/v1/organizations/#{org.key}/members"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(items: have_length(4))
    end

    it "403s if the customer is not a member" do
      membership.destroy

      get "/v1/organizations/#{org.key}/members"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "You don't have permissions with that organization."),
      )
    end
  end

  # POST

  describe "GET v1/organizations/:org_identifier/services" do
    it "returns a list of all available services" do
      get "/v1/organizations/#{org.key}/services"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(items: include(include(name: "shopify_customer_v1")))
    end
  end

  describe "POST /v1/organizations/:org_identifier/invite" do
    it "fails if request customer doesn't have admin privileges" do
      test_customer = Webhookdb::Fixtures.customer.create(email: "granny@aol.com")
      org.add_membership(customer: test_customer)

      post "/v1/organizations/#{org.key}/invite", email: "granny@aol.com"

      expect(last_response).to have_status(400)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "Permission denied: You don't have admin privileges with #{org.name}."),
      )
    end

    it "creates invited customer if no customer with that email exists" do
      customer.memberships_dataset.update(membership_role_id: admin_role.id)

      nonexistent_customer = Webhookdb::Customer[email: "bugsbunny@aol.com"]
      expect(nonexistent_customer).to be_nil

      post "/v1/organizations/#{org.key}/invite", email: "bugsbunny@aol.com"

      invited_customer = Webhookdb::Customer[email: "bugsbunny@aol.com"]
      expect(invited_customer).to_not be_nil
    end

    it "creates correct organization membership for the invited customer" do
      customer.memberships_dataset.update(membership_role_id: admin_role.id)

      post "/v1/organizations/#{org.key}/invite", email: "daffyduck@hotmail.com"

      invited_customer = Webhookdb::Customer[email: "daffyduck@hotmail.com"]
      membership = Webhookdb::OrganizationMembership[customer_id: invited_customer.id, organization_id: org.id]

      expect(membership).to_not be_nil
      expect(membership.verified).to eq(false)
      expect(membership.status).to eq("invited")
      expect(membership.invitation_code).to include("join-")
    end

    it "behaves correctly if customer membership does not exist" do
      customer.memberships_dataset.update(membership_role_id: admin_role.id)

      expect do
        post "/v1/organizations/#{org.key}/invite", email: "speedygonzalez@nasa.org"
      end.to perform_async_job(Webhookdb::Jobs::SendInvite)

      # returns correct status and response
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(message: match(/An invitation .* speedygonzalez@nasa\.org/))
    end

    it "behaves correctly if customer membership is unverified" do
      customer.memberships_dataset.update(membership_role_id: admin_role.id)

      test_customer = Webhookdb::Fixtures.customer.create(email: "elmerfudd@comcast.net")
      org.add_membership(customer: test_customer, verified: false, invitation_code: "join-oldcode")

      expect do
        post "/v1/organizations/#{org.key}/invite", email: "elmerfudd@comcast.net"
      end.to perform_async_job(Webhookdb::Jobs::SendInvite)

      # generates a new invitation code
      membership = Webhookdb::OrganizationMembership[customer: test_customer, organization: org]
      expect(membership.invitation_code).to_not eq("join-oldcode")

      # returns correct status and response
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(message: match(/An invitation .* elmerfudd@comcast\.net/))
    end

    it "returns 400 if customer is already a part of the organization" do
      customer.memberships_dataset.update(membership_role_id: admin_role.id)

      invited_customer = Webhookdb::Fixtures.customer.create(email: "porkypig@gmail.com")
      org.add_membership(customer: invited_customer)

      post "/v1/organizations/#{org.key}/invite", email: "porkypig@gmail.com"

      expect(last_response).to have_status(400)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "That person is already a member of the organization."),
      )
    end
  end

  describe "POST /v1/organizations/:org_identifier/remove_member" do
    it "fails if request customer doesn't have admin privileges" do
      test_customer = Webhookdb::Fixtures.customer.create(email: "yosemitesam@gmail.com")
      org.add_membership(customer: test_customer)

      post "/v1/organizations/#{org.key}/remove_member", email: "yosemitesam@gmail.com"

      expect(last_response).to have_status(400)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "Permission denied: You don't have admin privileges with #{org.name}."),
      )
    end

    it "fails if customer is not part of the organization" do
      customer.memberships_dataset.update(membership_role_id: admin_role.id)
      test_customer = Webhookdb::Fixtures.customer.create(email: "tweetybird@yahoo.com")
      expect(test_customer.memberships).to eq([])

      post "/v1/organizations/#{org.key}/remove_member", email: "tweetybird@yahoo.com"

      expect(last_response).to have_status(400)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "That user is not a member of #{org.name}."),
      )
    end

    it "removes user from organization and returns correct message" do
      customer.memberships_dataset.update(membership_role_id: admin_role.id)

      test_customer = Webhookdb::Fixtures.customer.create(email: "roadrunner@wb.com")
      org.add_membership(customer: test_customer, verified: true)

      post "/v1/organizations/#{org.key}/remove_member", email: "roadrunner@wb.com"

      test_customer_membership = org.memberships_dataset[customer: test_customer]

      expect(test_customer_membership).to be_nil
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        message: "roadrunner@wb.com is no longer a part of #{org.name}.",
      )
    end

    it "fails if the current customer is modifying their own role" do
      customer.memberships_dataset.update(membership_role_id: admin_role.id)
      post "v1/organizations/#{org.key}/remove_member", email: customer.email
      expect(last_response).to have_status(422)
    end

    it "succeeds if the current customer is modifying their own role and has confirmed" do
      _other_admin = org.add_membership(
        customer: Webhookdb::Fixtures.customer.create(email: "roadrunner@wb.com"),
        verified: true,
        membership_role: admin_role,
      )

      customer.memberships_dataset.update(membership_role_id: admin_role.id)
      post "v1/organizations/#{org.key}/remove_member", email: customer.email, guard_confirm: false
      expect(last_response).to have_status(200)
    end

    it "fails if the customer is the last admin in the org", db: :no_transaction do
      test_customer = Webhookdb::Fixtures.customer.create(email: "roadrunner@wb.com")
      org.add_membership(customer: test_customer, verified: true, membership_role: member_role)
      customer.memberships_dataset.update(membership_role_id: admin_role.id)

      post "v1/organizations/#{org.key}/remove_member", email: customer.email, guard_confirm: true
      expect(last_response).to have_status(409)
      expect(last_response).to have_json_body.that_includes(error: include(message: include("are the last admin in")))
    end
  end

  describe "POST /v1/organizations/:org_identifier/update" do
    it "fails if request customer doesn't have admin privileges" do
      post "/v1/organizations/#{org.key}/update", field: 'name="Acme Corp"'

      expect(last_response).to have_status(400)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "Permission denied: You don't have admin privileges with #{org.name}."),
      )
    end

    it "fails if proposed change field is not editable via the cli" do
      customer.memberships_dataset.update(membership_role_id: admin_role.id)

      post "/v1/organizations/#{org.key}/update", field: "opaque_id=foobar"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "That field is not editable from the command line"),
      )
    end

    it "updates org" do
      customer.memberships_dataset.update(membership_role_id: admin_role.id)

      post "/v1/organizations/#{org.key}/update", field: "billing_email=x@y.com"

      updated_org = Webhookdb::Organization[id: org.id]
      expect(updated_org.billing_email).to eq("x@y.com")
    end

    it "returns correct response" do
      customer.memberships_dataset.update(membership_role_id: admin_role.id)

      post "/v1/organizations/#{org.key}/update", field: "billing_email=x@y.com"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        message: "You have successfully updated the organization #{org.name}.",
      )
    end
  end

  describe "POST /v1/organizations/:org_identifier/close" do
    it "sends a message to Sentry" do
      org.memberships_dataset.update(membership_role_id: admin_role.id)

      expect(Sentry).to receive(:capture_message)

      post "/v1/organizations/#{org.key}/close"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        output: include("received the request"),
      )
    end

    it "fails if request customer doesn't have admin privileges" do
      org.memberships_dataset.update(membership_role_id: member_role.id)

      expect(Sentry).to_not receive(:capture_message)

      post "/v1/organizations/#{org.key}/close"

      expect(last_response).to have_status(400)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "Permission denied: You don't have admin privileges with #{org.name}."),
      )
    end
  end

  describe "POST /v1/organizations/:org_identifier/change_roles" do
    it "changes the roles of customers and returns correct response" do
      customer.memberships_dataset.update(membership_role_id: admin_role.id)

      membership_a = org.add_membership(customer: Webhookdb::Fixtures.customer.create(email: "pepelepew@yahoo.com"))
      membership_b = org.add_membership(customer: Webhookdb::Fixtures.customer.create(email: "marvinthe@martian.com"))

      post "v1/organizations/#{org.key}/change_roles",
           emails: "pepelepew@yahoo.com,marvinthe@martian.com", role_name: "member", guard_confirm: true

      memberships = org.memberships_dataset.where(membership_role_id: Webhookdb::Role[name: "member"].id)
      expect(memberships).to have_same_ids_as([membership_a, membership_b])

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        message: start_with("Success! These users"),
      )
    end

    it "errors if the customers are not a part of the organization" do
      customer.memberships_dataset.update(membership_role_id: admin_role.id)
      Webhookdb::Fixtures.customer.create(email: "sylvester@yahoo.com")

      post "/v1/organizations/#{org.key}/change_roles",
           emails: "sylvester@yahoo.com", role_name: "member", guard_confirm: true

      expect(last_response).to have_status(400)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "Those emails do not belong to members of #{org.name}."),
      )
    end

    it "fails if request customer doesn't have admin privileges" do
      org.add_membership(customer: Webhookdb::Fixtures.customer.create(email: "foghornleghorn@gmail.com"))

      post "/v1/organizations/#{org.key}/change_roles",
           emails: "foghornleghorn@gmail.com", role_name: "member", guard_confirm: true

      expect(last_response).to have_status(400)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "Permission denied: You don't have admin privileges with #{org.name}."),
      )
    end

    it "fails if the current customer is modifying their own role" do
      customer.memberships_dataset.update(membership_role_id: admin_role.id)

      post "v1/organizations/#{org.key}/change_roles",
           emails: customer.email, role_name: "member"

      expect(last_response).to have_status(422)
    end

    it "succeeds if the current customer is modifying their own role and has confirmed" do
      _other_admin = org.add_membership(
        customer: Webhookdb::Fixtures.customer.create(email: "pepelepew@yahoo.com"),
        membership_role_id: admin_role.id,
      )
      customer.memberships_dataset.update(membership_role_id: admin_role.id)

      post "v1/organizations/#{org.key}/change_roles",
           emails: customer.email, role_name: "member", guard_confirm: true

      expect(last_response).to have_status(200)
    end

    it "fails if the customer is modifying the last admin in the org", db: :no_transaction do
      customer.memberships_dataset.update(membership_role_id: admin_role.id)

      post "v1/organizations/#{org.key}/change_roles",
           emails: customer.email, role_name: "member", guard_confirm: true

      expect(last_response).to have_status(409)
      expect(last_response).to have_json_body.that_includes(error: include(message: include("you are the last admin")))

      expect(customer.memberships_dataset[organization: org]).to(have_attributes(membership_role: be === admin_role))
    end
  end

  describe "POST v1/organizations/create" do
    it "creates new organization and creates membership for current customer" do
      post "v1/organizations/create", name: "Acme Corporation"

      new_org = Webhookdb::Organization[name: "Acme Corporation"]
      expect(new_org).to_not be_nil
      expect(new_org.key).to eq("acme_corporation")
      expect(new_org.billing_email).to eq(customer.email)

      expect(new_org.memberships_dataset.where(customer:).all).to have_length(1)
    end

    it "returns correct message" do
      post "v1/organizations/create", name: "Acme Corporation"

      expect(last_response).to have_status(200)
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
      org.add_membership(customer:, invitation_code: "join-abcxyz")

      post "v1/organizations/join", invitation_code: "join-abcxyz"

      expect(last_response).to have_status(200)
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

  describe "POST /v1/organizations/:org_identifier/rename" do
    it "fails if request customer doesn't have admin privileges" do
      post "/v1/organizations/#{org.key}/rename", name: "Acme Corp"

      expect(last_response).to have_status(400)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "Permission denied: You don't have admin privileges with #{org.name}."),
      )
    end

    it "renames org" do
      org.update(name: "alice", key: "nat")
      customer.memberships_dataset.update(membership_role_id: admin_role.id)

      post "/v1/organizations/#{org.key}/rename", name: "bob"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        message: "The organization 'nat' has been renamed from 'alice' to 'bob'.",
      )
      expect(org.refresh).to have_attributes(name: "bob")
    end
  end
end
