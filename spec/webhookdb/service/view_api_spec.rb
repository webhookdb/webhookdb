# frozen_string_literal: true

require "rack/test"

require "webhookdb/service"
require "webhookdb/service/helpers"
require "webhookdb/service/view_api"

class Webhookdb::Service::TestViewApi < Webhookdb::Service
  include Webhookdb::Service::ViewApi
  helpers Webhookdb::Service::Helpers

  get :viewform do
    raise Webhookdb::Service::ViewApi::FormError.new("some error", 422)
  end
end

RSpec.describe Webhookdb::Service::ViewApi, :db do
  include Rack::Test::Methods

  let(:app) { Webhookdb::Service::TestViewApi.build_app }

  describe "form errors" do
    it "returns a json error by default" do
      get "/viewform"

      expect(last_response).to have_status(422)
      expect(last_response_json_body).to eq(error: {message: "some error", status: 422})
    end

    it "renders an html page if there are view params" do
      viewparams = {
        path: "messages/web/install.liquid",
        vars: {"app_name" => "Testing"},
        content_type: "application/xml",
      }

      get "/viewform", {}, {cookie: "whdbviewparams=#{URI.encode_uri_component(viewparams.to_json)}"}

      expect(last_response).to have_status(422)
      expect(last_response.headers).to include("content-type" => "application/xml")
      expect(last_response.body).to include("<title>WebhookDB | Sync Testing</title>")
    end

    it "returns a json error if the view params cannot be parsed" do
      get "/viewform", {}, {cookie: "whdbviewparams=notjson"}

      expect(last_response).to have_status(422)
      expect(last_response_json_body).to eq(error: {message: "some error", status: 422})
    end
  end
end
