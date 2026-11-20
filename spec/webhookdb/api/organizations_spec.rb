# frozen_string_literal: true

require "webhookdb/api/organizations"
require "webhookdb/async"

RSpec.describe Webhookdb::API::Organizations, :async, :db do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }

  let!(:customer) { Webhookdb::Fixtures.customer.create }
  let!(:org) { Webhookdb::Fixtures.organization.create(name: "fake@lithic.tech Org") }
  let(:org_membership_fac) { Webhookdb::Fixtures.organization_membership(organization: org) }
  let!(:membership) { org_membership_fac.verified.create(customer:) }
  let!(:admin_role) { Webhookdb::Role.admin_role }
  let!(:member_role) { Webhookdb::Role.non_admin_role }

  before(:all) do
    Webhookdb::Async.setup_tests
  end

  before(:each) do
    login_as(customer)
  end

  describe "GET /v1/organizations/:org_identifier" do
    it "returns organization associated with id passed as route param" do
      get "/v1/organizations/#{org.id}"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(id: org.id)
    end

    it "returns organization associated with key as route param" do
      get "/v1/organizations/#{org.key}"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(id: org.id)
    end

    it "returns organization associated with id passed as query param" do
      get "/v1/organizations/-", org: org.id

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(id: org.id)
    end

    it "returns organization associated with key passed as query param" do
      get "/v1/organizations/-", org: org.key

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(id: org.id)
    end

    it "returns organization associated with name passed as query param" do
      get "/v1/organizations/-", org: org.name

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(id: org.id)
    end

    it "403s if the org does not exist" do
      get "/v1/organizations/fake_org"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "There is no organization with that identifier."),
      )
    end

    it "403s if customer doesn't have permissions" do
      membership.destroy

      get "/v1/organizations/#{org.id}"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "You don't have permissions with that organization."),
      )
    end
  end

  describe "GET /v1/organizations/:org_identifier/members" do
    it "returns all customers associated with organization" do
      Array.new(3) { org_membership_fac.verified.create }
      org_membership_fac.invite.create

      get "/v1/organizations/#{org.key}/members"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(items: have_length(5))
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
      expect(last_response).to have_json_body.that_includes(items: include(include(name: "stripe_customer_v1")))
    end
  end

  describe "POST /v1/organizations/:org_identifier/invite" do
    it "fails if request customer doesn't have admin privileges" do
      org_membership_fac.verified.customer(email: "granny@aol.com").create

      post "/v1/organizations/#{org.key}/invite", email: "granny@aol.com"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: /admin privileges/),
      )
    end

    it "creates invited customer if no customer with that email exists" do
      membership.update(membership_role: admin_role)

      post "/v1/organizations/#{org.key}/invite", email: "bugsbunny@aol.com"

      expect(last_response).to have_status(200)
      expect(Webhookdb::Customer.all).to include(have_attributes(email: "bugsbunny@aol.com"))
    end

    it "creates correct organization membership for the invited customer" do
      membership.update(membership_role: admin_role)

      post "/v1/organizations/#{org.key}/invite", email: "daffyduck@hotmail.com"

      expect(last_response).to have_status(200)
      invited_customer = Webhookdb::Customer[email: "daffyduck@hotmail.com"]
      membership = Webhookdb::OrganizationMembership[customer_id: invited_customer.id, organization_id: org.id]
      expect(membership).to have_attributes(
        verified: false,
        status: "invited",
        invitation_code: include("join-"),
      )
    end

    it "behaves correctly if customer membership does not exist" do
      membership.update(membership_role: admin_role)

      expect do
        post "/v1/organizations/#{org.key}/invite", email: "speedygonzalez@nasa.org"
      end.to perform_async_job(Webhookdb::Jobs::SendInvite)

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(message: match(/An invitation .* speedygonzalez@nasa\.org/))
    end

    it "behaves correctly if customer membership is unverified" do
      membership.update(membership_role: admin_role)

      membership = org_membership_fac.invite.customer(email: "elmerfudd@comcast.net").code("join-oldcode").create

      expect do
        post "/v1/organizations/#{org.key}/invite", email: "elmerfudd@comcast.net"
      end.to perform_async_job(Webhookdb::Jobs::SendInvite)

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(message: match(/An invitation .* elmerfudd@comcast\.net/))
      expect(membership.refresh.invitation_code).to_not eq("join-oldcode")
    end

    it "returns 400 if customer is already a part of the organization" do
      membership.update(membership_role: admin_role)

      org_membership_fac.verified.customer(email: "porkypig@gmail.com").create

      post "/v1/organizations/#{org.key}/invite", email: "porkypig@gmail.com"

      expect(last_response).to have_status(400)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "That person is already a member of the organization."),
      )
    end
  end

  describe "POST /v1/organizations/:org_identifier/remove_member" do
    it "fails if request customer doesn't have admin privileges" do
      org_membership_fac.verified.customer(email: "yosemitesam@gmail.com").create

      post "/v1/organizations/#{org.key}/remove_member", email: "yosemitesam@gmail.com"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: /admin privileges/),
      )
    end

    it "fails if customer is not part of the organization" do
      membership.update(membership_role: admin_role)
      test_customer = Webhookdb::Fixtures.customer.create(email: "tweetybird@yahoo.com")
      expect(test_customer.all_memberships).to eq([])

      post "/v1/organizations/#{org.key}/remove_member", email: "tweetybird@yahoo.com"

      expect(last_response).to have_status(400)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "That user is not a member of #{org.name}."),
      )
    end

    it "removes user from organization and returns correct message" do
      membership.update(membership_role: admin_role)

      mem = org_membership_fac.verified.customer(email: "roadrunner@wb.com").create

      post "/v1/organizations/#{org.key}/remove_member", email: "roadrunner@wb.com"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        message: "roadrunner@wb.com is no longer a part of #{org.name}.",
      )
      expect(mem.class.dataset.where(id: mem.id).all).to be_empty
    end

    it "fails if the current customer is modifying their own role" do
      membership.update(membership_role: admin_role)
      post "v1/organizations/#{org.key}/remove_member", email: customer.email
      expect(last_response).to have_status(422)
    end

    it "succeeds if the current customer is modifying their own role and has confirmed" do
      _other_admin = org.add_membership(
        customer: Webhookdb::Fixtures.customer.create(email: "roadrunner@wb.com"),
        verified: true,
        membership_role: admin_role,
      )

      membership.update(membership_role: admin_role)
      post "v1/organizations/#{org.key}/remove_member", email: customer.email, guard_confirm: false
      expect(last_response).to have_status(200)
    end

    it "fails if the customer is the last admin in the org", db: :no_transaction do
      test_customer = Webhookdb::Fixtures.customer.create(email: "roadrunner@wb.com")
      org.add_membership(customer: test_customer, verified: true, membership_role: member_role)
      membership.update(membership_role: admin_role)

      post "v1/organizations/#{org.key}/remove_member", email: customer.email, guard_confirm: true
      expect(last_response).to have_status(409)
      expect(last_response).to have_json_body.that_includes(error: include(message: include("are the last admin in")))
    end
  end

  describe "POST /v1/organizations/:org_identifier/update" do
    it "fails if request customer doesn't have admin privileges" do
      post "/v1/organizations/#{org.key}/update", field: "name", value: '"Acme Corp"'

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: /admin privileges/),
      )
    end

    it "fails if proposed change field is not editable via the cli" do
      membership.update(membership_role: admin_role)

      post "/v1/organizations/#{org.key}/update", field: "opaque_id", value: "foobar"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "That field is not editable from the command line"),
      )
    end

    it "updates org" do
      membership.update(membership_role: admin_role)

      post "/v1/organizations/#{org.key}/update", field: "billing_email", value: "x@y.com"

      updated_org = Webhookdb::Organization[id: org.id]
      expect(updated_org.billing_email).to eq("x@y.com")
    end

    it "returns correct response" do
      membership.update(membership_role: admin_role)

      post "/v1/organizations/#{org.key}/update", field: "billing_email", value: "x@y.com"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        message: "You have successfully updated the organization #{org.name}.",
      )
    end
  end

  describe "POST /v1/organizations/:org_identifier/close", :async do
    it "sends a developer alert" do
      membership.update(membership_role: admin_role)

      expect do
        post "/v1/organizations/#{org.key}/close"

        expect(last_response).to have_status(200)
        expect(last_response).to have_json_body.that_includes(
          output: include("received the request"),
        )
      end.to publish("webhookdb.developeralert.emitted").with_payload(
        contain_exactly(
          {
            "subsystem" => "Close Account",
            "emoji" => ":no_pedestrians:",
            "fallback" => "Org fake_lithic_tech_org requested removal",
            "fields" => [
              {"title" => "Org Key", "value" => "fake_lithic_tech_org", "short" => true},
              {"title" => "Org Name", "value" => "fake@lithic.tech Org", "short" => true},
              {"title" => "Customer", "value" => "(#{customer.id}) #{customer.email}", "short" => false},
            ],
          },
        ),
      )
      expect(Webhookdb::SystemLogEvent.all).to contain_exactly(
        have_attributes(actor: be === customer, title: "Organization Closure Requested"),
      )
    end

    it "fails if request customer doesn't have admin privileges" do
      post "/v1/organizations/#{org.key}/close"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: /admin privileges/),
      )
    end
  end

  describe "POST /v1/organizations/:org_identifier/change_roles" do
    it "changes the roles of customers and returns correct response" do
      membership.update(membership_role: admin_role)

      membership_a = org_membership_fac.verified.create(
        customer: Webhookdb::Fixtures.customer.create(email: "pepelepew@yahoo.com"),
      )
      membership_b = org_membership_fac.verified.create(
        customer: Webhookdb::Fixtures.customer.create(email: "marvinthe@martian.com"),
      )

      post "v1/organizations/#{org.key}/change_roles",
           emails: "pepelepew@yahoo.com,marvinthe@martian.com", role_name: "member", guard_confirm: true

      memberships = org.all_memberships_dataset.where(membership_role_id: Webhookdb::Role[name: "member"].id).all
      expect(memberships).to have_same_ids_as([membership_a, membership_b])

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        message: start_with("Success! These users"),
      )
    end

    it "errors if the customers are not a part of the organization" do
      membership.update(membership_role: admin_role)
      Webhookdb::Fixtures.customer.create(email: "sylvester@yahoo.com")

      post "/v1/organizations/#{org.key}/change_roles",
           emails: "sylvester@yahoo.com", role_name: "member", guard_confirm: true

      expect(last_response).to have_status(400)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "Those emails do not belong to members of #{org.name}."),
      )
    end

    it "fails if request customer doesn't have admin privileges" do
      org_membership_fac.verified.customer(email: "foghornleghorn@gmail.com").create

      post "/v1/organizations/#{org.key}/change_roles",
           emails: "foghornleghorn@gmail.com", role_name: "member", guard_confirm: true

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: /admin privileges/),
      )
    end

    it "fails if the current customer is modifying their own role" do
      membership.update(membership_role: admin_role)

      post "v1/organizations/#{org.key}/change_roles",
           emails: customer.email, role_name: "member"

      expect(last_response).to have_status(422)
    end

    it "succeeds if the current customer is modifying their own role and has confirmed" do
      _other_admin = org.add_verified_membership(
        customer: Webhookdb::Fixtures.customer.create(email: "pepelepew@yahoo.com"),
        membership_role: admin_role,
      )
      membership.update(membership_role: admin_role)

      post "v1/organizations/#{org.key}/change_roles",
           emails: customer.email, role_name: "member", guard_confirm: true

      expect(last_response).to have_status(200)
    end

    it "fails if the customer is modifying the last admin in the org", db: :no_transaction do
      membership.update(membership_role: admin_role)

      post "v1/organizations/#{org.key}/change_roles",
           emails: customer.email, role_name: "member", guard_confirm: true

      expect(last_response).to have_status(409)
      expect(last_response).to have_json_body.that_includes(error: include(message: include("you are the last admin")))

      expect(customer.all_memberships_dataset[organization: org]).to(
        have_attributes(membership_role: be === admin_role),
      )
    end
  end

  describe "POST v1/organizations/create" do
    it "creates new organization and creates membership for current customer" do
      membership.update(is_default: true)

      post "v1/organizations/create", name: "Acme Corporation"

      expect(last_response).to have_json_body.that_includes(id: be > org.id)

      new_org = Webhookdb::Organization[name: "Acme Corporation"]
      expect(new_org).to have_attributes(
        key: "acme_corporation",
        billing_email: customer.email,
      )
      expect(new_org.all_memberships_dataset.all).to contain_exactly(
        have_attributes(customer:, is_default: true),
      )
      expect(membership.refresh).to have_attributes(is_default: false)
    end

    it "returns correct message" do
      post "v1/organizations/create", name: "Acme Corporation"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        message: include("Organization created with identifier 'acme_corporation'."),
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
      membership = org_membership_fac.invite.code("join-abcxyz").create(customer:)

      post "v1/organizations/join", invitation_code: "join-abcxyz"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(message: "Congratulations! You are now a member of #{org.name}.")

      expect(membership.refresh).to have_attributes(verified: true, is_default: true)
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

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: /admin privileges/),
      )
    end

    it "renames org" do
      org.update(name: "alice", key: "nat")
      membership.update(membership_role: admin_role)

      post "/v1/organizations/#{org.key}/rename", name: "bob"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        message: "The organization 'nat' has been renamed from 'alice' to 'bob'.",
      )
      expect(org.refresh).to have_attributes(name: "bob")
    end
  end
end
