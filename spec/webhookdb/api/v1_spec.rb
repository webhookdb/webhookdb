# frozen_string_literal: true

require "webhookdb/api"

RSpec.describe Webhookdb::API::V1, :db do
  include Rack::Test::Methods

  test_service = Class.new(Webhookdb::API::V1) do
    customer_entity = Class.new(Webhookdb::API::BaseEntity) do
      expose :id
    end
    get :entity do
      present Webhookdb::Customer.first, with: customer_entity, message: "hello"
    end
  end

  let(:app) { test_service.build_app }

  it "can represent a customer with a message" do
    customer = Webhookdb::Fixtures.customer.create

    get "/v1/entity"

    expect(last_response).to have_status(200)
    expect(last_response_json_body).to eq(id: customer.id, message: "hello")
  end
end
