# frozen_string_literal: true

require "webhookdb/admin_api/auth"

RSpec.describe Webhookdb::AdminAPI::Auth, :db do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }
  let(:password) { "Password1!" }
  let(:customer) { Webhookdb::Fixtures.customer.password(password).create }
  let(:admin) { Webhookdb::Fixtures.customer.admin.password(password).create }

  describe "POST /v1/auth/login" do
    it "logs in the user with the given username and password" do
      post("/v1/auth/login", email: admin.email, password:)

      expect(last_response).to have_status(200)
      expect(last_response).to have_session_cookie
    end

    it "errors for bad creds" do
      post "/v1/auth/login", email: admin.email, password: "hello"
      expect(last_response).to have_status(401)

      post("/v1/auth/login", email: admin.email + "z", password:)
      expect(last_response).to have_status(401)
    end

    it "errors if not admin" do
      post("/v1/auth/login", email: customer.email, password:)

      expect(last_response).to have_status(401)
    end
  end

  describe "GET /v1/auth" do
    it "200s if the customer is an admin and authed as an admin" do
      login_as_admin(admin)

      get "/v1/auth"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(id: admin.id, impersonated: false)
    end

    it "returns the admin customer, even if impersonated" do
      login_as_admin(admin)

      target = Webhookdb::Fixtures.customer.create
      post "/v1/auth/impersonate/#{target.id}"
      expect(last_response).to have_status(200)

      get "/v1/auth"
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(id: admin.id, impersonated: true)
    end

    it "401s if the customer is not authed" do
      get "/v1/auth"

      expect(last_response).to have_status(401)
    end

    it "401s if the customer did not auth as an admin (even if they are now)" do
      login_as(admin)

      get "/v1/auth"

      expect(last_response).to have_status(401)
    end

    it "401s if the customer has authed as an admin but no longer has the role" do
      login_as_admin(admin)
      admin.remove_role(Webhookdb::Role.admin_role)

      get "/v1/auth"

      expect(last_response).to have_status(401)
    end
  end

  describe "POST /v1/auth/impersonate/:id" do
    let(:target) { Webhookdb::Fixtures.customer.create }

    it "impersonates the given customer" do
      login_as_admin(admin)

      post "/v1/auth/impersonate/#{target.id}"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(id: target.id, impersonated: true)
    end

    it "replaces an existing impersonated customer" do
      login_as_admin(admin)
      post "/v1/auth/impersonate/#{target.id}"

      other_target = Webhookdb::Fixtures.customer.create
      post "/v1/auth/impersonate/#{other_target.id}"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(id: other_target.id, impersonated: true)
    end

    it "404s if the customer does not exist" do
      login_as_admin(admin)

      post "/v1/auth/impersonate/0"

      expect(last_response).to have_status(404)
    end
  end

  describe "DELETE /v1/auth/impersonate" do
    it "unimpersonates an impersonated customer" do
      login_as_admin(admin)

      target = Webhookdb::Fixtures.customer.create
      post "/v1/auth/impersonate/#{target.id}"
      expect(last_response).to have_status(200)

      delete "/v1/auth/impersonate"
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(id: admin.id, impersonated: false)
    end

    it "noops if no customer is impersonated" do
      login_as_admin(admin)

      delete "/v1/auth/impersonate"
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(id: admin.id, impersonated: false)
    end
  end
end
