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
        customer = Webhookdb::Customer.last
        expect(customer).to_not be_nil
        expect(customer).to have_attributes(email: email)
      end

      it "lowercases the email" do
        post "/v1/auth", customer_params.merge(email: "HEARME@ROAR.coM")

        expect(last_response).to have_status(202)
        expect(last_response).to have_json_body.that_includes(email: "hearme@roar.com")
        expect(Webhookdb::Customer.last).to have_attributes(email: "hearme@roar.com")
      end

      it "trims spaces from email" do
        post "/v1/auth", customer_params.merge(email: " barf@sb.com ")

        expect(last_response).to have_status(202)
        expect(last_response).to have_json_body.that_includes(email: "barf@sb.com")
        expect(Webhookdb::Customer.last).to have_attributes(email: "barf@sb.com")
      end

      it "creates a new email reset code for the customer" do
        post "/v1/auth", email: email

        expect(last_response).to have_status(202)
        customer = Webhookdb::Customer.last
        new_code = customer.refresh.reset_codes.first
        expect(new_code).to_not be_expired
        expect(new_code).to have_attributes(transport: "email")
      end

      it "creates new organization and membership for current customer if doesn't exist" do
        post "/v1/auth", email: email

        new_org = Webhookdb::Organization[name: "Org for #{email}"]
        expect(new_org).to_not be_nil
        expect(new_org.billing_email).to eq(email)

        customer = Webhookdb::Customer.last
        expect(new_org.memberships_dataset.where(customer: customer).all).to have_length(1)
      end
    end

    describe "for an email matching an existing customer" do
      let!(:customer) { Webhookdb::Fixtures.customer(**customer_params).create }

      it "expires and creates a new email reset code for the customer" do
        existing_code = Webhookdb::Fixtures.reset_code(customer: customer).email.create

        post "/v1/auth", email: email

        expect(last_response).to have_status(202)
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

    it "errors if a customer is logged in" do
      login_as(customer)
      post "/v1/auth/login_otp", email: email, token: "abcd"
      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(error: include(code: "already_logged_in"))
    end

    it "errors if the email does not belong to an existing customer" do
      post "/v1/auth/login_otp", email: "a@b.c", token: "abcd"
      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(error: include(code: "user_not_found"))
    end

    it "establishes an auth session and returns the default_org" do
      code = customer.add_reset_code(transport: "email")
      default_org = Webhookdb::Fixtures.organization.create
      customer.add_membership(organization: default_org)

      post "/v1/auth/login_otp", email: email, token: code.token

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(organization: include(id: default_org.id))
      expect(last_response).to have_session_cookie
      expect(code.refresh).to have_attributes(used: true)
    end

    it "400s if the token does not belong to the current customer" do
      code = Webhookdb::Fixtures.reset_code.create

      post "/v1/auth/login_otp", email: email, token: code.token

      expect(last_response).to have_status(400)
      expect(last_response).to have_json_body.
        that_includes(error: include(message: "Invalid verification code"))
    end

    it "400s if the token is invalid" do
      code = Webhookdb::Fixtures.reset_code(customer: customer).create
      code.expire!

      post "/v1/auth/login_otp", email: email, token: code.token

      expect(last_response).to have_status(400)
      expect(last_response).to have_json_body.
        that_includes(error: include(message: "Invalid verification code"))
    end

    it "logs the user in if the code is invalid and auth skipping is enabled for the customer email" do
      Webhookdb::Customer.skip_authentication_allowlist = ["*@cats.org"]
      customer.update(email: "meow@cats.org")

      post "/v1/auth/login_otp", email: "meow@cats.org", token: "a"

      expect(last_response).to have_status(200)
      expect(last_response.body).to eq("null")
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
