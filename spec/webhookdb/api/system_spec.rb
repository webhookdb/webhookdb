# frozen_string_literal: true

require "webhookdb/api/system"

RSpec.describe Webhookdb::API::System do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }

  describe "GET /" do
    it "redirects to terminal" do
      get "/"
      expect(last_response).to have_status(302)
      expect(last_response.headers).to include("Location" => "/terminal/")
    end
  end

  describe "GET /healthz" do
    it "returns 200" do
      get "/healthz"
      expect(last_response).to have_status(200)
      expect(last_response_json_body).to eq({o: "k"})
    end
  end

  describe "GET /service_health" do
    it "returns status about services" do
      get "/service_health"
      expect(last_response).to have_status(200)
      expect(last_response_json_body).to include(
        autoscale_depth: be_a(Integer),
        autoscale_started: have_length("1970-01-01T00:00:00Z".length),
        db: be_a(Float),
        redis: be_a(Float),
      )
    end
  end

  describe "GET /statusz" do
    it "returns 200" do
      get "/statusz"
      expect(last_response).to have_status(200)
      expect(last_response_json_body).to include(:env, :version, :release, :log_level)
    end
  end

  describe "GET /debug/echo" do
    it "prints the request" do
      expect do
        get "/debug/echo", x: 1
      end.to output(/example\.org/).to_stdout
      expect(last_response).to have_status(200)
    end
  end

  describe "POST /sink" do
    it "204s" do
      post "/sink"
      expect(last_response).to have_status(204)
    end
  end
end
