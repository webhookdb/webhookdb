# frozen_string_literal: true

require "webhookdb/admin_api/customers"
require "webhookdb/api/behaviors"

RSpec.describe Webhookdb::AdminAPI::Customers, :db do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }
  let(:admin) { Webhookdb::Fixtures.customer.admin.create }

  before(:each) do
    login_as_admin(admin)
  end

  describe "GET /admin/v1/customers" do
    it "returns all customers" do
      u = Array.new(2) { Webhookdb::Fixtures.customer.create }

      get "/admin/v1/customers"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(items: have_same_ids_as(admin, *u))
    end

    it_behaves_like "an endpoint capable of search" do
      let(:url) { "/admin/v1/customers" }
      let(:search_term) { "ZIM" }

      def make_matching_items
        return [
          Webhookdb::Fixtures.customer(email: "zim@zam.zom").create,
          Webhookdb::Fixtures.customer(name: "Zim Zam").create,
        ]
      end

      def make_non_matching_items
        return [
          admin,
          Webhookdb::Fixtures.customer(name: "wibble wobble", email: "qux@wux.com").create,
        ]
      end
    end

    it_behaves_like "an endpoint with pagination" do
      let(:url) { "/admin/v1/customers" }
      def make_item(i)
        # Sorting is newest first, so the first items we create need to the the oldest.
        created = Time.now - i.days
        return admin.update(created_at: created) if i.zero?
        return Webhookdb::Fixtures.customer.create(created_at: created)
      end
    end

    it_behaves_like "an endpoint with customer-supplied ordering" do
      let(:url) { "/admin/v1/customers" }
      let(:order_by_field) { "note" }
      def make_item(i)
        return admin.update(note: i.to_s) if i.zero?
        return Webhookdb::Fixtures.customer.create(created_at: Time.now + rand(1..100).days, note: i.to_s)
      end
    end
  end

  describe "GET /admin/v1/customers/:id" do
    it "returns the customer" do
      get "/admin/v1/customers/#{admin.id}"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(:roles, id: admin.id)
    end

    it "404s if the customer does not exist" do
      get "/admin/v1/customers/0"

      expect(last_response).to have_status(404)
    end
  end

  describe "POST /admin/v1/customers/:id" do
    it "updates the customer" do
      customer = Webhookdb::Fixtures.customer.create

      post "/admin/v1/customers/#{customer.id}", name: "b 2", email: "b@gmail.com"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(id: customer.id, name: "b 2", email: "b@gmail.com")
    end

    it "replaces roles" do
      customer = Webhookdb::Fixtures.customer.with_role("existing").with_role("to_remove").create
      Webhookdb::Role.create(name: "to_add")

      post "/admin/v1/customers/#{customer.id}", roles: ["existing", "to_add"]

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(roles: contain_exactly("existing", "to_add"))
      expect(customer.refresh.roles.map(&:name)).to contain_exactly("existing", "to_add")
    end
  end
end
