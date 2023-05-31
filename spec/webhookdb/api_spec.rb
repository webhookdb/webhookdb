# frozen_string_literal: true

require "rack/test"

require "webhookdb/api"

class Webhookdb::API::TestV1Api < Webhookdb::API::V1
  params do
    optional :str, prompt: "Enter string"
    optional :int, type: Integer, prompt: "Enter int"
    optional :bool, type: Boolean, prompt: "Enter bool"
  end
  post :types do
    present(params.to_h)
  end

  params do
    optional :param, prompt: "X"
  end
  post :string do
    present({})
  end

  params do
    optional :param, prompt: {message: "X"}
  end
  post :hash do
    present({})
  end

  params do
    optional :param, type: Boolean, prompt: {message: "X"}
  end
  post :boolparam do
    present({param: params[:param]})
  end

  params do
    optional :param, type: Integer, prompt: {message: "X"}
  end
  post :intparam do
    present({param: params[:param]})
  end

  params do
    optional :param, prompt: {message: "X", secret: true}
  end
  post :secret do
    present({})
  end

  params do
    optional :param, prompt: {message: "X:", confirm: true}
  end
  post :confirm do
    present({})
  end

  params do
    optional :param, prompt: {message: "X:", optional: true}
  end
  post :optional do
    present({})
  end

  params do
    optional :param, prompt: {message: "X:", disable: ->(request) { request.env["HTTP_NOPROMPT"] == "yes" }}
  end
  post :disabled do
    present(params.to_h)
  end

  params do
    optional :param, prompt: "X:", default: "hi"
  end
  post :default do
    present(params.to_h)
  end

  params do
    requires :org_id
    requires :sint_identifier
  end
  post :sint_lookup do
    org = Webhookdb::Organization[id: params[:org_id]]
    sint = lookup_service_integration!(org, params[:sint_identifier])
    status 200
    present sint, with: Webhookdb::API::ServiceIntegrationEntity
  end

  params do
    optional :blank_string, type: String
    requires :nonblank_string, type: String
  end
  post :control_chars do
    present(params.to_h)
  end
end

RSpec.describe Webhookdb::API, :db do
  include Rack::Test::Methods

  let(:app) { Webhookdb::API::TestV1Api.build_app }

  describe "prompt validator to 422 for missing params" do
    it "noops if no param is missing" do
      post "/v1/string", param: "x"

      expect(last_response).to have_status(201)
      expect(last_response.headers).to_not include("Whdb-Prompt")
    end

    it "errors with the correct state machine if any param is missing" do
      post "/v1/types", int: 2
      expect(last_response).to have_status(422)
      expect(last_response_json_body[:error][:state_machine_step]).to include(
        prompt: "Enter string", prompt_is_secret: false,
      )
      expect(last_response.headers).to include("Whdb-Prompt" => "str")

      step = last_response_json_body[:error][:state_machine_step]
      new_body = step[:post_params].merge(step[:post_params_value_key] => "1")
      post step[:post_to_url], new_body
      expect(last_response).to have_status(422)

      step = last_response_json_body[:error][:state_machine_step]
      new_body = step[:post_params].merge(step[:post_params_value_key] => true)
      post step[:post_to_url], new_body
      expect(last_response).to have_status(201)
      expect(last_response_json_body).to eq({bool: true, int: 2, str: "1"})
    end

    it "can handle true/false booleans" do
      post "/v1/boolparam", param: 10
      expect(last_response).to have_status(400)

      post "/v1/boolparam", param: 1
      expect(last_response).to have_status(201)
      expect(last_response_json_body).to eq(param: true)

      post "/v1/boolparam", param: 0
      expect(last_response).to have_status(201)
      expect(last_response_json_body).to eq(param: false)

      post "/v1/boolparam"
      expect(last_response).to have_status(422)

      post "/v1/boolparam", param: nil
      expect(last_response).to have_status(422)

      post "/v1/boolparam", param: true
      expect(last_response).to have_status(201)

      post "/v1/boolparam", param: false
      expect(last_response).to have_status(201)
    end

    it "can handle blankable integers" do
      post "/v1/intparam", param: 1
      expect(last_response).to have_status(201)
      expect(last_response_json_body).to eq(param: 1)

      post "/v1/intparam", param: 0
      expect(last_response).to have_status(201)
      expect(last_response_json_body).to eq(param: 0)

      post "/v1/intparam"
      expect(last_response).to have_status(422)

      post "/v1/intparam", param: nil
      expect(last_response).to have_status(422)

      post "/v1/intparam", param: "spam"
      expect(last_response).to have_status(400)
    end

    it "can be specified with a string" do
      post "/v1/string"
      expect(last_response).to have_status(422)

      post "/v1/string", param: nil
      expect(last_response).to have_status(422)

      post "/v1/string", param: ""
      expect(last_response).to have_status(422)

      post "/v1/string", param: "0"
      expect(last_response).to have_status(201)
    end

    it "can be specified with a hash" do
      post "/v1/hash"
      expect(last_response).to have_status(422)

      post "/v1/hash", param: "0"
      expect(last_response).to have_status(201)
    end

    it "can prompt for a secret" do
      post "/v1/secret"
      expect(last_response).to have_status(422)
      expect(last_response_json_body[:error][:state_machine_step]).to include(prompt_is_secret: true)

      post "/v1/secret", param: nil
      expect(last_response).to have_status(422)

      post "/v1/secret", param: ""
      expect(last_response).to have_status(422)

      post "/v1/secret", param: "1"
      expect(last_response).to have_status(201)
    end

    it "can prompt for confirmation" do
      post "/v1/confirm"
      expect(last_response).to have_status(422)

      post "/v1/confirm", param: nil
      expect(last_response).to have_status(422)

      post "/v1/confirm", param: ""
      expect(last_response).to have_status(201)

      post "/v1/confirm", param: "1"
      expect(last_response).to have_status(201)
    end

    it "can prompt as optional" do
      post "/v1/optional"
      expect(last_response).to have_status(422)

      post "/v1/optional", param: nil
      expect(last_response).to have_status(201)

      post "/v1/optional", param: ""
      expect(last_response).to have_status(201)

      post "/v1/optional", param: "1"
      expect(last_response).to have_status(201)
    end

    it "can be disabled" do
      post "/v1/disabled"
      expect(last_response).to have_status(422)

      header "NOPROMPT", "no"
      post "/v1/disabled"
      expect(last_response).to have_status(422)

      post "/v1/disabled", param: nil
      expect(last_response).to have_status(422)

      header "NOPROMPT", "yes"
      post "/v1/disabled"
      expect(last_response).to have_status(201)
      expect(last_response_json_body).to eq({})

      post "/v1/disabled", param: nil
      expect(last_response).to have_status(201)
      expect(last_response_json_body).to eq(param: nil)
    end

    it "ignores a default" do
      post "/v1/default"

      expect(last_response).to have_status(422)
    end
  end

  describe "assertions" do
    describe "if using requires" do
      let(:app) do
        Class.new(Webhookdb::API::V1) do
          params do
            requires :param, prompt: "X"
          end
          post(:path) { body "" }
        end.build_app
      end

      it "errors" do
        post "/v1/path"
        expect(last_response).to have_status(500)
        expect(last_response.body).to include("must use optional for param")
      end
    end

    describe "if using allow_blank" do
      let(:app) do
        Class.new(Webhookdb::API::V1) do
          params do
            optional :param, allow_blank: false, prompt: "X"
          end
          post(:path) { body "" }
        end.build_app
      end

      it "errors" do
        post "/v1/path"
        expect(last_response).to have_status(500)
        expect(last_response.body).to include("allow_blank must not be set")
      end
    end
  end

  describe "lookup_service_integration!" do
    let(:org) { Webhookdb::Fixtures.organization.create }
    let(:sint) { Webhookdb::Fixtures.service_integration.create(organization: org) }

    it "can return a service integration based on opaque_id" do
      post "/v1/sint_lookup", sint_identifier: sint.opaque_id, org_id: org.id

      expect(last_response).to have_status(200)
      lookup_opaque_id = last_response_json_body[:opaque_id]
      expect(lookup_opaque_id).to eq(sint.opaque_id)
    end

    it "can return a service integration based on table_name" do
      post "/v1/sint_lookup", sint_identifier: sint.table_name, org_id: org.id

      expect(last_response).to have_status(200)
      lookup_opaque_id = last_response_json_body[:opaque_id]
      expect(lookup_opaque_id).to eq(sint.opaque_id)
    end

    it "can return a service integration based on service_name" do
      post "/v1/sint_lookup", sint_identifier: sint.service_name, org_id: org.id

      expect(last_response).to have_status(200)
      lookup_opaque_id = last_response_json_body[:opaque_id]
      expect(lookup_opaque_id).to eq(sint.opaque_id)
    end

    it "403s if there are multiple integrations with a given service name" do
      Webhookdb::Fixtures.service_integration.create(organization: org)

      post "/v1/sint_lookup", sint_identifier: sint.service_name, org_id: org.id

      expect(last_response).to have_status(409)
      expect(last_response.body).to include(
        "multiple integrations with that service name. Try again using an integration id, or a table name",
      )
    end

    it "403s if there are no integrations associated with the identifier" do
      post "/v1/sint_lookup", sint_identifier: "foo", org_id: org.id

      expect(last_response).to have_status(403)
      expect(last_response.body).to include("There is no service integration")
    end
  end

  describe "before validation" do
    it "removes control characters from string inputs" do
      post "/v1/control_chars", blank_string: "[D[A[C[A", nonblank_string: "foo[b"
      expect(last_response_json_body).to eq(blank_string: "", nonblank_string: "foo")
    end
  end
end
