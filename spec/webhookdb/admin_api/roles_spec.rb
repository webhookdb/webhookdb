# frozen_string_literal: true

require "webhookdb/admin_api/roles"

RSpec.describe Webhookdb::AdminAPI::Roles, :db do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }
  let(:admin) { Webhookdb::Fixtures.customer.admin.create }

  before(:each) do
    login_as_admin(admin)
  end

  describe "GET /admin/v1/roles" do
    it "returns all roles" do
      c = Webhookdb::Role.create(name: "c")
      d = Webhookdb::Role.create(name: "d")
      b = Webhookdb::Role.create(name: "b")

      get "/admin/v1/roles"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(items: have_same_ids_as(Webhookdb::Role.admin_role, b, c, d).ordered)
    end
  end
end
