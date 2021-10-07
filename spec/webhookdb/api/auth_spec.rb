# frozen_string_literal: true

require "webhookdb/api/auth"

RSpec.describe Webhookdb::API::Auth, :db do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }

  let(:email) { "jane@farmers.org" }
  let(:customer_params) do
    {email: email}
  end

  describe "POST /v1/auth" do
    it "errors if a customer is logged in" do
      login_as(Webhookdb::Fixtures.customer.create)
      post "/v1/auth", email: email
      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(error: include(code: "already_logged_in"))
    end

    describe "for an email that does not match an existing customer" do
      it "creates a customer" do
        post "/v1/auth", **customer_params

        expect(last_response).to have_status(202)
        expect(last_response).to have_json_body.that_includes(output: /Welcome to WebhookDB/)
        customer = Webhookdb::Customer.last
        expect(customer).to_not be_nil
        expect(customer).to have_attributes(email: email)
      end
    end

    describe "for an email matching an existing customer" do
      let!(:customer) { Webhookdb::Fixtures.customer(**customer_params).create }

      it "expires and creates a new email reset code for the customer" do
        existing_code = Webhookdb::Fixtures.reset_code(customer: customer).email.create

        post "/v1/auth", email: email

        expect(last_response).to have_status(202)
        expect(last_response).to have_json_body.that_includes(output: /Welcome back/)
        expect(existing_code.refresh).to be_expired
        new_code = customer.refresh.reset_codes.first
        expect(new_code).to_not be_expired
        expect(new_code).to have_attributes(transport: "email")

        expect(Webhookdb::Customer.all).to(have_length(1))
      end
    end
  end

  describe "POST /v1/auth/login_otp" do
    let!(:customer) { Webhookdb::Fixtures.customer(**customer_params).create }
    let(:opaque_id) { customer.opaque_id }

    it "errors if a customer is logged in" do
      login_as(customer)
      post "/v1/auth/login_otp/#{opaque_id}", value: "abcd"
      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(error: include(code: "already_logged_in"))
    end

    it "fails if the id does not belong to an existing customer" do
      post "/v1/auth/login_otp/myid", value: "abcd"
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(output: /Sorry, no one with that email/)
    end

    it "establishes an auth session and returns the default_org" do
      code = customer.add_reset_code(transport: "email")
      default_org = Webhookdb::Fixtures.organization.create
      customer.add_membership(organization: default_org)

      post "/v1/auth/login_otp/#{opaque_id}", value: code.token

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(output: /Welcome!/)
      expect(last_response).to have_session_cookie
      expect(code.refresh).to have_attributes(used: true)
    end

    it "fails if the token does not belong to the current customer" do
      code = Webhookdb::Fixtures.reset_code.create

      post "/v1/auth/login_otp/#{opaque_id}", value: code.token

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(error_code: "invalid_otp")
    end

    it "fails if the token is invalid" do
      code = Webhookdb::Fixtures.reset_code(customer: customer).create
      code.expire!

      post "/v1/auth/login_otp/#{opaque_id}", value: code.token

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(error_code: "invalid_otp")
    end

    it "logs the user in if the code is invalid and auth skipping is enabled for the customer email" do
      Webhookdb::Customer.skip_authentication_allowlist = ["*@cats.org"]
      customer.update(email: "meow@cats.org")

      post "/v1/auth/login_otp/#{opaque_id}", value: "a"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(output: /Welcome!/)
    ensure
      Webhookdb::Customer.reset_configuration
    end
  end

  describe "POST /v1/auth/logout" do
    it "removes the cookies" do
      post "/v1/auth/logout"

      expect(last_response).to have_status(200)
      expect(last_response["Set-Cookie"]).to include("=deleted; path=/; expires=Thu, 01 Jan 1970 00:00:00")
    end
  end
end
