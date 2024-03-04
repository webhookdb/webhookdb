# frozen_string_literal: true

require "webhookdb/admin_api/data_provider"

RSpec.describe Webhookdb::AdminAPI::DataProvider, :db do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }
  let(:admin) { Webhookdb::Fixtures.customer.admin.create }

  before(:each) do
    login_as_admin(admin)
  end

  describe "POST /v1/data_provider/get_one" do
    it "returns the resource" do
      c = Webhookdb::Fixtures.customer.create
      post "/v1/data_provider/get_one", resource: "customers", id: c.id
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(data: include(id: c.id))
    end

    it "403s for an invalid id" do
      post "/v1/data_provider/get_one", resource: "customers", id: 1
      expect(last_response).to have_status(403)
    end

    it "400s for an invalid type" do
      post "/v1/data_provider/get_one", resource: "whales", id: 1
      expect(last_response).to have_status(400)
    end

    it "401s if the user is not an admin" do
      logout
      post "/v1/data_provider/get_one", resource: "customers", id: 0
      expect(last_response).to have_status(401)
    end

    it "does not include 'message' from the public api" do
      c = Webhookdb::Fixtures.customer.create
      post "/v1/data_provider/get_one", resource: "customers", id: c.id
      expect(last_response).to have_status(200)
      expect(last_response_json_body[:data].keys).to contain_exactly(
        :created_at, :email, :id, :name, :note, :soft_deleted_at, :updated_at,
      )
    end
  end

  describe "POST /v1/data_provider/get_list" do
    it "returns resources" do
      o = Array.new(2) { Webhookdb::Fixtures.organization.create }

      post "/v1/data_provider/get_list", resource: "organizations"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(data: have_same_ids_as(*o), total: 2)
    end

    it "paginates" do
      Array.new(5) { |i| Webhookdb::Fixtures.organization.create(name: "org-#{i}") }

      post "/v1/data_provider/get_list", resource: "organizations", pagination: {page: 1, per_page: 2}
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(
          total: 5,
          data: contain_exactly(include(name: "org-4"), include(name: "org-3")),
        )

      post "/v1/data_provider/get_list", resource: "organizations", pagination: {page: 2, per_page: 2}
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(data: contain_exactly(include(name: "org-2"), include(name: "org-1")))

      post "/v1/data_provider/get_list", resource: "organizations", pagination: {page: 3, per_page: 2}
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(data: contain_exactly(include(name: "org-0")))

      post "/v1/data_provider/get_list", resource: "organizations", pagination: {page: 4, per_page: 2}
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(data: [], total: 5)
    end

    it "sorts" do
      Webhookdb::Fixtures.organization.create(name: "org-Y")
      Webhookdb::Fixtures.organization.create(name: "org-Z")
      Webhookdb::Fixtures.organization.create(name: "org-X")

      post "/v1/data_provider/get_list", resource: "organizations"
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(data: match([include(name: "org-X"), include(name: "org-Z"), include(name: "org-Y")]))

      post "/v1/data_provider/get_list", resource: "organizations", sort: {field: "name", order: "DESC"}
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(data: match([include(name: "org-Z"), include(name: "org-Y"), include(name: "org-X")]))

      post "/v1/data_provider/get_list", resource: "organizations", sort: {field: "name", order: "ASC"}
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(data: match([include(name: "org-X"), include(name: "org-Y"), include(name: "org-Z")]))
    end

    it "filters" do
      Webhookdb::Fixtures.organization.create(name: "org-X")
      Webhookdb::Fixtures.organization.create(name: "org-Y")

      post "/v1/data_provider/get_list", resource: "organizations", filter: {name: "org-Y"}
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(data: match([include(name: "org-Y")]))
    end

    it "searches text search columns" do
      Webhookdb::Fixtures.organization.create(name: "org Xavier")
      Webhookdb::Fixtures.organization.create(name: "org-Y")
      Webhookdb::Organization.text_search_reindex_all

      post "/v1/data_provider/get_list", resource: "organizations", filter: {q: "Xavier"}
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(data: match([include(name: "org Xavier")]))
    end

    it "sorts, filters, and searches" do
      Webhookdb::Fixtures.organization.create(name: "org-Y")
      Webhookdb::Fixtures.organization.create(name: "org-Z")
      Webhookdb::Fixtures.organization.create(name: "org-X", stripe_customer_id: "x")
      Webhookdb::Fixtures.organization.create(name: "org-X2", stripe_customer_id: "x")
      Webhookdb::Fixtures.organization.create(name: "org-X3", stripe_customer_id: "x")
      Webhookdb::Fixtures.organization.create(name: "nothing", stripe_customer_id: "x")
      Webhookdb::Organization.text_search_reindex_all

      post "/v1/data_provider/get_list",
           resource: "organizations",
           filter: {q: "org", stripe_customer_id: "x"},
           sort: {field: "key", order: "ASC"},
           pagination: {page: 1, per_page: 2}
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(data: match([include(key: "org_x"), include(key: "org_x2")]), total: 3)
    end
  end

  describe "POST /v1/data_provider/get_many" do
    it "returns identified resources" do
      o1 = Webhookdb::Fixtures.organization.create
      o2 = Webhookdb::Fixtures.organization.create

      post "/v1/data_provider/get_many",
           resource: "organizations",
           ids: [o1.id, 0]
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(data: have_same_ids_as(o1))
    end
  end

  describe "POST /v1/data_provider/get_many_reference" do
    it "returns related resources" do
      org = Webhookdb::Fixtures.organization.create
      membership = Webhookdb::Fixtures.organization_membership.verified.create(organization: org)
      other_membership = Webhookdb::Fixtures.organization_membership.verified.create

      post "/v1/data_provider/get_many_reference",
           resource: "organization_memberships", target: "organization_id", id: org.id

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(data: have_same_ids_as(membership), total: 1)
    end

    it "paginates, filters, and sorts" do
      org = Webhookdb::Fixtures.organization.create
      fac = Webhookdb::Fixtures.organization_membership(organization: org).verified
      admin1 = fac.admin.create
      admin2 = fac.admin.create
      admin3 = fac.admin.create
      mem = fac.create

      post "/v1/data_provider/get_many_reference",
           resource: "organization_memberships",
           target: "organization_id",
           id: org.id,
           pagination: {page: 2, per_page: 2},
           sort: {field: "id", order: "ASC"},
           filter: {membership_role_id: Webhookdb::Role.admin_role.id}

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(data: have_same_ids_as(admin3))
    end

    it "can work for join tables" do
      c = Webhookdb::Fixtures.customer.create
      r = Webhookdb::Fixtures.role.create
      c.add_role r

      post "/v1/data_provider/get_many_reference",
           resource: "customer_roles",
           target: "customer_id",
           id: c.id

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(data: contain_exactly(include(customer: include(id: c.id), role: include(id: r.id))))
    end

    it "can show organization database sizes" do
      o = Webhookdb::Fixtures.organization.create
      o.prepare_database_connections
      sint = Webhookdb::Fixtures.service_integration.create(organization: o)
      sint.replicator.create_table

      post "/v1/data_provider/get_many_reference",
           resource: "replicated_databases",
           target: "organization_id",
           id: o.id

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(data: [
                        {
                          id: sint.table_name,
                          table_name: sint.table_name,
                          size_pretty: "32 kB",
                          size: 0,
                        },
                      ])
    ensure
      o.remove_related_database
    end
  end

  describe "round-tripping" do
    testcases = [
      ["backfill_jobs", Webhookdb::Fixtures.backfill_job],
      ["customers", Webhookdb::Fixtures.customer],
      ["customer_reset_codes", Webhookdb::Fixtures.reset_code],
      ["logged_webhooks", Webhookdb::Fixtures.logged_webhook],
      ["message_bodies", Webhookdb::Fixtures.message_body],
      ["message_deliveries", Webhookdb::Fixtures.message_delivery],
      ["organization_database_migrations", Webhookdb::Fixtures.organization_database_migration],
      ["organization_memberships", Webhookdb::Fixtures.organization_membership.invite],
      ["organizations", Webhookdb::Fixtures.organization],
      ["roles", Webhookdb::Fixtures.role],
      ["service_integrations", Webhookdb::Fixtures.service_integration],
      ["saved_queries", Webhookdb::Fixtures.saved_query],
      ["saved_views", Webhookdb::Fixtures.saved_view],
      ["subscriptions", Webhookdb::Fixtures.subscription],
      ["sync_targets", Webhookdb::Fixtures.sync_target],
      ["webhook_subscriptions", Webhookdb::Fixtures.webhook_subscription],
      ["webhook_subscription_deliveries", Webhookdb::Fixtures.webhook_subscription_delivery],
    ]
    testcases.each do |(rez, fac)|
      it "can be done for #{rez}" do
        m = fac.create
        post "/v1/data_provider/get_one", resource: rez, id: m.id
        expect(last_response).to have_status(200)
        expect(last_response).to have_json_body.that_includes(data: include(id: m.id))
      end
    end
  end
end
