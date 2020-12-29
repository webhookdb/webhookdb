# frozen_string_literal: true

require "webhookdb/api/auth"

RSpec.describe Webhookdb::API::Auth, :db do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }

  let(:email) { "jane@farmers.org" }
  let(:other_email) { "diff-" + email }
  let(:password) { "1234abcd!" }
  let(:other_password) { password + "abc" }
  let(:first_name) { "David" }
  let(:last_name) { "Graeber" }
  let(:phone) { "1234567890" }
  let(:full_phone) { "11234567890" }
  let(:other_phone) { "1234567999" }
  let(:other_full_phone) { "11234567999" }
  let(:fmt_phone) { "(123) 456-7890" }
  let(:timezone) { "America/Juneau" }
  let(:customer_params) do
    {first_name: first_name, last_name: last_name, email: email, phone: phone, password: password, timezone: timezone}
  end
  let(:customer_create_params) { customer_params.merge(phone: full_phone) }

  describe "POST /v1/auth" do
    let!(:customer) { Webhookdb::Fixtures.customer(**customer_create_params).create }

    it "returns 200 with the customer data and a session cookie if phone is verified and password matches" do
      post "/v1/auth", phone: phone, password: password

      expect(last_response).to have_status(200)
      expect(last_response).to have_session_cookie
      expect(last_response).to have_json_body.
        that_includes(first_name: first_name, last_name: last_name, phone: fmt_phone)
    end

    it "returns 401 if the password does not match" do
      post "/v1/auth", phone: phone, password: "a" + password

      expect(last_response).to have_status(401)
      expect(last_response.body).to include("Incorrect password")
    end

    it "returns 401 if the phone has no customer" do
      post "/v1/auth", phone: "111-111-1111", password: password

      expect(last_response).to have_status(401)
      expect(last_response.body).to include("No customer with that phone")
    end

    it "succeeds if email is verified and password matches" do
      post "/v1/auth", email: email, password: password

      expect(last_response).to have_status(200)
      expect(last_response).to have_session_cookie
      expect(last_response).to have_json_body.that_includes(id: customer.id)
    end

    it "returns 401 if email has no customer" do
      post "/v1/auth", email: "a@b.c", password: password

      expect(last_response).to have_status(401)
      expect(last_response.body).to include("No customer with that email")
    end

    it "replaces the auth of an already-logged-in customer" do
      other_cust = Webhookdb::Fixtures.customer.create
      login_as(other_cust)

      post "/v1/auth", phone: phone, password: password

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(id: customer.id)
    end
  end

  describe "POST /v1/auth/verify" do
    let(:customer) { Webhookdb::Fixtures.customer(**customer_create_params).unverified.create }

    before(:each) do
      login_as(customer)
    end

    it "tries to verify the customer" do
      code = customer.add_reset_code(transport: "sms")
      expect(customer).to_not be_phone_verified
      expect(customer).to_not be_email_verified

      post "/v1/auth/verify", token: code.token

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(phone_verified: true)
      customer.refresh
      expect(customer).to be_phone_verified
      expect(customer).to_not be_email_verified
    end

    it "tries to verify the customer email" do
      code = customer.add_reset_code(transport: "email")
      expect(customer).to_not be_email_verified
      expect(customer).to_not be_phone_verified

      post "/v1/auth/verify", token: code.token

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(email_verified: true)
      customer.refresh
      expect(customer).to be_email_verified
      expect(customer).to_not be_phone_verified
    end

    it "400s if the token does not belong to the current customer" do
      code = Webhookdb::Fixtures.reset_code.create

      post "/v1/auth/verify", token: code.token

      expect(last_response).to have_status(400)
      expect(last_response).to have_json_body.
        that_includes(error: include(message: "Invalid verification code"))
    end

    it "400s if the token is invalid" do
      code = Webhookdb::Fixtures.reset_code(customer: customer).create
      code.expire!

      post "/v1/auth/verify", token: code.token

      expect(last_response).to have_status(400)
      expect(last_response).to have_json_body.
        that_includes(error: include(message: "Invalid verification code"))
    end
  end

  describe "POST /v1/auth/resend_verification" do
    let(:customer) { Webhookdb::Fixtures.customer(**customer_create_params).create }
    let!(:sms_code) { Webhookdb::Fixtures.reset_code(customer: customer).sms.create }
    let!(:email_code) { Webhookdb::Fixtures.reset_code(customer: customer).email.create }

    before(:each) do
      login_as(customer)
    end

    it "expires and creates a new sms reset code for the customer" do
      post "/v1/auth/resend_verification", transport: "sms"

      expect(last_response).to have_status(204)
      expect(sms_code.refresh).to be_expired
      expect(email_code.refresh).to_not be_expired
      new_code = customer.refresh.reset_codes.first
      expect(new_code).to_not be_expired
      expect(new_code).to have_attributes(transport: "sms")
    end

    it "expires and creates a new email reset code for the customer" do
      post "/v1/auth/resend_verification", transport: "email"

      expect(last_response).to have_status(204)
      expect(sms_code.refresh).to_not be_expired
      expect(email_code.refresh).to be_expired
      new_code = customer.refresh.reset_codes.first
      expect(new_code).to_not be_expired
      expect(new_code).to have_attributes(transport: "email")
    end
  end

  describe "DELETE /v1/auth" do
    it "removes the cookies" do
      delete "/v1/auth"

      expect(last_response).to have_status(204)
      expect(last_response["Set-Cookie"]).to include("=deleted; path=/; expires=Thu, 01 Jan 1970 00:00:00")
    end
  end
end
