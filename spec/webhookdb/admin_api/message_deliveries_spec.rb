# frozen_string_literal: true

require "webhookdb/admin_api/message_deliveries"
require "webhookdb/api/behaviors"

RSpec.describe Webhookdb::AdminAPI::MessageDeliveries, :db do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }
  let(:admin) { Webhookdb::Fixtures.customer.admin.create }

  before(:each) do
    login_as_admin(admin)
  end

  describe "GET /v1/message_deliveries" do
    it "returns all deliveries (no bodies)" do
      deliveries = Array.new(2) { Webhookdb::Fixtures.message_delivery.create }

      get "/v1/message_deliveries"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(items: have_same_ids_as(deliveries))
      expect(last_response_json_body[:items][0]).to_not include(:bodies)
    end

    it_behaves_like "an endpoint capable of search" do
      let(:url) { "/v1/message_deliveries" }
      let(:search_term) { "ZIM" }

      def make_matching_items
        return [
          Webhookdb::Fixtures.message_delivery(to: "ZIM@zam.com").create,
          Webhookdb::Fixtures.message_delivery(template: "zim_zam").create,
        ]
      end

      def make_non_matching_items
        return [
          Webhookdb::Fixtures.message_delivery(to: "zam@zam.com", template: "zam_zam").create,
        ]
      end
    end

    it_behaves_like "an endpoint with pagination" do
      let(:url) { "/v1/message_deliveries" }
      def make_item(i)
        return Webhookdb::Fixtures.message_delivery.create(created_at: Time.now - i.hour)
      end
    end

    it_behaves_like "an endpoint with customer-supplied ordering" do
      let(:url) { "/v1/message_deliveries" }
      let(:order_by_field) { "to" }
      def make_item(i)
        return Webhookdb::Fixtures.message_delivery.create(to: i.to_s + "@lithic.tech")
      end
    end
  end

  describe "GET /v1/customers/:id/message_deliveries" do
    it "returns all deliveries that to the customer" do
      customer = Webhookdb::Fixtures.customer.create
      to_customer = Webhookdb::Fixtures.message_delivery.with_recipient(customer).create
      to_email = Webhookdb::Fixtures.message_delivery.to(customer.email).create
      to_neither = Webhookdb::Fixtures.message_delivery.with_recipient.create

      get "/v1/customers/#{customer.id}/message_deliveries"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(items: have_same_ids_as(to_email, to_customer).ordered)
    end
  end

  describe "GET /v1/message_deliveries/:id" do
    it "returns the delivery with the given ID and its bodies" do
      del = Webhookdb::Fixtures.message_delivery.with_body.with_body.create

      get "/v1/message_deliveries/#{del.id}"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(id: del.id, bodies: have_length(2))
    end

    it "404s if the delivery does not exist" do
      get "/v1/message_deliveries/0"

      expect(last_response).to have_status(404)
    end
  end

  describe "GET /v1/message_deliveries/last" do
    it "returns the last delivery" do
      d1 = Webhookdb::Fixtures.message_delivery.create
      d2 = Webhookdb::Fixtures.message_delivery.create

      get "/v1/message_deliveries/last"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(id: d2.id)
    end
  end
end
