# frozen_string_literal: true

require "webhookdb/api/me"

RSpec.describe Webhookdb::API::Me, :db do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }
  let(:customer) { Webhookdb::Fixtures.customer.create }

  before(:each) do
    login_as(customer)
  end

  describe "GET /v1/me" do
    it "returns the authed customer" do
      get "/v1/me"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(email: customer.email)
    end

    it "errors if the customer is soft deleted" do
      customer.soft_delete

      get "/v1/me"

      expect(last_response).to have_status(401)
    end

    it "401s if not logged in" do
      logout

      get "/v1/me"

      expect(last_response).to have_status(401)
    end
  end

  describe "POST /v1/me/update" do
    it "updates the given fields on the customer" do
      post "/v1/me/update", name: "Hassan", other_thing: "abcd"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(name: "Hassan")

      expect(customer.refresh).to have_attributes(name: "Hassan")
    end
  end

  describe "GET /v1/me/settings" do
  end

  describe "PATCH /v1/me/settings" do
    it "can update the customer name" do
      patch "/v1/me/settings", name: "Matz"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(name: "Matz")
    end
  end
end
