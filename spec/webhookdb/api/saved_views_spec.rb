# frozen_string_literal: true

require "webhookdb/api/saved_views"

RSpec.describe Webhookdb::API::SavedViews, :db do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }
  let(:customer) { Webhookdb::Fixtures.customer.create }
  let(:org) { Webhookdb::Fixtures.organization.with_admin(customer).create }

  before(:each) do
    login_as(customer)
  end

  describe "GET /v1/organizations/:key/saved_views" do
    it "returns a list of saved views for the organization" do
      sv = Webhookdb::Fixtures.saved_view(organization: org).create
      Webhookdb::Fixtures.saved_view.create

      get "/v1/organizations/#{org.key}/saved_views"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(items: contain_exactly(include(name: sv.name)))
    end

    it "returns a message if organization has no saved views" do
      new_org = Webhookdb::Fixtures.organization.with_member(customer).create
      get "/v1/organizations/#{new_org.key}/saved_views"
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(message: include("have any saved views"))
    end
  end

  describe "POST /v1/organizations/:key/saved_views/create_or_replace" do
    before(:each) do
      org.prepare_database_connections
      org.add_feature_role(Webhookdb::SavedView.feature_role)
    end

    after(:each) do
      org.remove_related_database
    end

    it "creates or replaces a view" do
      post "/v1/organizations/#{org.key}/saved_views/create_or_replace", name: "myq", sql: "SELECT 1 AS x"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(name: "myq")
      expect(org.saved_views).to contain_exactly(
        have_attributes(created_by: customer, sql: "SELECT 1 AS x", name: "myq"),
      )
    end

    it "fails if the SQL cannot be run" do
      post "/v1/organizations/#{org.key}/saved_views/create_or_replace", name: "myq", sql: "SELECT invalid"

      expect(last_response).to have_status(422)
      expect(last_response).to have_json_body.that_includes(
        error: include(state_machine_step: include(prompt: /new query/, output: /was invalid/)),
      )
    end

    it "fails if the view name is invalid" do
      post "/v1/organizations/#{org.key}/saved_views/create_or_replace", name: "hi-there", sql: "SELECT 1"

      expect(last_response).to have_status(422)
      expect(last_response).to have_json_body.that_includes(
        error: include(state_machine_step: include(prompt: /new name/, output: /not a valid view name/)),
      )
    end

    it "errors if the org does not have the saved_views feature role" do
      org.remove_all_feature_roles

      post "/v1/organizations/#{org.key}/saved_views/create_or_replace", name: "myq", sql: "SELECT 1 AS x"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(error: include(message: /not enabled/))
    end

    it "errors if the user is not an admin" do
      customer.verified_memberships.first.update(membership_role: Webhookdb::Role.non_admin_role)

      post "/v1/organizations/#{org.key}/saved_views/create_or_replace", name: "myq", sql: "SELECT 1"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(error: include(message: /admin to modify views/))
    end
  end

  describe "POST /v1/organizations/:key/saved_views/delete" do
    it "deletes the view with the given name" do
      sv = Webhookdb::Fixtures.saved_view(organization: org).create

      post "/v1/organizations/#{org.key}/saved_views/delete", {name: sv.name}

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        message: /deleted the saved view/,
      )
      expect(sv).to be_destroyed
    end

    it "403s if the query does not belong to the org or does not exist" do
      sv = Webhookdb::Fixtures.saved_view.create

      post "/v1/organizations/#{org.key}/saved_views/delete", {name: sv.name}

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: /There is no view with that name/),
      )
    end

    it "errors if the user is not an admin" do
      sv = Webhookdb::Fixtures.saved_view(organization: org).create
      customer.verified_memberships.first.update(membership_role: Webhookdb::Role.non_admin_role)

      post "/v1/organizations/#{org.key}/saved_views/delete", {name: sv.name}

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: /admin to modify views/),
      )
    end
  end
end
