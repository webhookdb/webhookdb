# frozen_string_literal: true

require "rack/test"

require "webhookdb/api"

class Webhookdb::API::TestV1Api < Webhookdb::API::V1
  params do
    optional :x, prompt: "Enter param x"
    optional :y, prompt: "Enter param y"
    optional :z, type: Integer, prompt: "Enter param z"
  end
  post "prompt_missing_params" do
    status 200
    present({})
  end

  params do
    requires :x, prompt: "Enter param x"
  end
  post "prompt_missing_required" do
    status 200
    present({})
  end

  params do
    requires :x, prompt: "Enter param x"
    requires :y, prompt: ["Enter param y", :ascii_only?]
    requires :z, prompt: ["Enter param z", ->(x) { Integer(x.blank? ? 0 : x).positive? }]
  end
  post "prompt_if" do
    status 200
    present({})
  end
end

RSpec.describe Webhookdb::API, :db do
  include Rack::Test::Methods

  let(:app) { Webhookdb::API::TestV1Api.build_app }

  describe "prompt validator to 426 for missing params" do
    it "noops if no param is missing" do
      post "/v1/prompt_missing_params", x: 1, y: 2, z: 3

      expect(last_response).to have_status(200)
    end

    it "errors with the correct state machine if any param is missing" do
      post "/v1/prompt_missing_params", y: 2
      expect(last_response).to have_status(426)

      step = last_response_json_body[:error][:state_machine_step]
      new_body = step[:post_params].merge(step[:post_params_value_key] => "1")
      post step[:post_to_url], new_body
      expect(last_response).to have_status(426)

      step = last_response_json_body[:error][:state_machine_step]
      new_body = step[:post_params].merge(step[:post_params_value_key] => 3)
      post step[:post_to_url], new_body
      expect(last_response).to have_status(200)
    end

    it "can be used with required" do
      post "/v1/prompt_missing_required"
      expect(last_response).to have_status(426)
    end

    it "can use conditional promps" do
      post "/v1/prompt_if"
      expect(last_response).to have_status(426)
      expect(last_response_json_body[:error][:state_machine_step]).to include(post_params_value_key: "x")

      post "/v1/prompt_if", {x: ""}
      expect(last_response).to have_status(426)
      expect(last_response_json_body[:error][:state_machine_step]).to include(post_params_value_key: "x")

      post "/v1/prompt_if", {x: "1"}
      expect(last_response).to have_status(426)
      expect(last_response_json_body[:error][:state_machine_step]).to include(post_params_value_key: "y")

      post "/v1/prompt_if", {x: "1", y: "\u0400"}
      expect(last_response).to have_status(426)
      expect(last_response_json_body[:error][:state_machine_step]).to include(post_params_value_key: "y")

      post "/v1/prompt_if", {x: "1", y: "\u0400"}
      expect(last_response).to have_status(426)
      expect(last_response_json_body[:error][:state_machine_step]).to include(post_params_value_key: "y")

      post "/v1/prompt_if", {x: "1", y: "1"}
      expect(last_response).to have_status(426)
      expect(last_response_json_body[:error][:state_machine_step]).to include(post_params_value_key: "z")

      post "/v1/prompt_if", {x: "1", y: "1", z: ""}
      expect(last_response).to have_status(426)
      expect(last_response_json_body[:error][:state_machine_step]).to include(post_params_value_key: "z")

      post "/v1/prompt_if", {x: "1", y: "1", z: "0"}
      expect(last_response).to have_status(426)
      expect(last_response_json_body[:error][:state_machine_step]).to include(post_params_value_key: "z")

      post "/v1/prompt_if", {x: "1", y: "1", z: "1"}
      expect(last_response).to have_status(200)
    end
  end
end
