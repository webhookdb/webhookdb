# frozen_string_literal: true

require "webhookdb/api/error_handlers"

RSpec.describe Webhookdb::API::ErrorHandlers, :db do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }
  let(:customer) { Webhookdb::Fixtures.customer.create }
  let(:org) { Webhookdb::Fixtures.organization.with_admin(customer).create }

  before(:each) do
    login_as(customer)
  end

  describe "GET /v1/organizations/:key/error_handlers" do
    it "returns a list of error handlers for the organization" do
      eh = Webhookdb::Fixtures.organization_error_handler(organization: org).create
      Webhookdb::Fixtures.organization_error_handler.create

      get "/v1/organizations/#{org.key}/error_handlers"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(items: contain_exactly(include(id: eh.opaque_id)))
    end

    it "returns a message if organization has no error handlers" do
      new_org = Webhookdb::Fixtures.organization.with_member(customer).create
      get "/v1/organizations/#{new_org.key}/error_handlers"
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(message: include("have any error handlers"))
    end
  end

  describe "POST /v1/organizations/:key/error_handlers/create" do
    it "creates an error handler" do
      post "/v1/organizations/#{org.key}/error_handlers/create", url: "https://foo.bar"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(url: "https://foo.bar")
      expect(org.error_handlers).to contain_exactly(
        have_attributes(created_by: customer, url: "https://foo.bar"),
      )
    end

    it "fails if the URL is not valid (invalid url)" do
      post "/v1/organizations/#{org.key}/error_handlers/create", url: ":123"

      expect(last_response).to have_status(400)
      expect(last_response).to have_json_body.that_includes(error: include(message: /URL is malformed/))
    end

    it "fails if the URL is not valid (invalid scheme)" do
      post "/v1/organizations/#{org.key}/error_handlers/create", url: "ftp://foo.bar"

      expect(last_response).to have_status(400)
      expect(last_response).to have_json_body.that_includes(error: include(message: /URL is malformed/))
    end

    it "allows a sentry: protocol" do
      post "/v1/organizations/#{org.key}/error_handlers/create", url: "sentry://foo.bar"

      expect(last_response).to have_status(200)
    end

    it "errors if the customer is not an org admin" do
      org.all_memberships.first.update(membership_role: Webhookdb::Role.non_admin_role)

      post "/v1/organizations/#{org.key}/error_handlers/create", url: "https://foo.bar"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "You must be an org admin to modify error handlers."),
      )
    end
  end

  describe "GET /v1/organizations/:key/error_handlers/:id" do
    it "returns the error handler" do
      eh = Webhookdb::Fixtures.organization_error_handler(organization: org).create

      get "/v1/organizations/#{org.key}/error_handlers/#{eh.opaque_id}"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(url: eh.url, id: eh.opaque_id)
    end

    it "403s if the handler with the given opaque id does not exist" do
      sq = Webhookdb::Fixtures.organization_error_handler.create

      get "/v1/organizations/#{org.key}/error_handlers/#{sq.opaque_id}"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: include("There is no error handler with that")),
      )
    end
  end

  describe "POST /v1/organizations/:key/error_handlers/:id/delete" do
    it "deletes the handler and returns correct response" do
      eh = Webhookdb::Fixtures.organization_error_handler(organization: org).create

      post "/v1/organizations/#{org.key}/error_handlers/#{eh.opaque_id}/delete"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        message: /You have successfully deleted the error handler /,
      )
      expect(eh).to be_destroyed
    end

    it "403s if request customer isn't an admin" do
      org.all_memberships.first.update(membership_role: Webhookdb::Role.non_admin_role)
      eh = Webhookdb::Fixtures.organization_error_handler(organization: org).create

      post "/v1/organizations/#{org.key}/error_handlers/#{eh.opaque_id}/delete"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "You must be an org admin to modify error handlers."),
      )
    end

    it "403s if the handler does not belong to the org or does not exist" do
      eh = Webhookdb::Fixtures.organization_error_handler.create

      post "/v1/organizations/#{org.key}/error_handlers/#{eh.opaque_id}/delete"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: /There is no error handler with that id/),
      )
    end
  end
end
