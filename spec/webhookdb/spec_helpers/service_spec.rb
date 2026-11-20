# frozen_string_literal: true

require "ostruct"
require "rspec/matchers/fail_matchers"

require "webhookdb/spec_helpers/service"

RSpec.describe Webhookdb::SpecHelpers::Service do
  include RSpec::Matchers::FailMatchers

  describe "have_status matcher" do
    let(:response) { Rack::MockResponse.new(203, {}, "") }

    it "passes if the response status matches" do
      expect do
        expect(response).to have_status(203)
      end.to_not raise_error
    end

    it "fails if the response status does not match" do
      expect do
        expect(response).to have_status(500)
      end.to fail_with(/expected response status 500/i)
    end

    it "has a failure message containing the response body" do
      response = Rack::MockResponse.new(203, {}, "response body")
      expect do
        expect(response).to have_status(400)
      end.to raise_error(/body: response body/i)
    end

    it "multiline prints the backtrace if included" do
      response = Rack::MockResponse.new(203, {}, {x: 1, error: {backtrace: "a\nb"}}.to_json)
      expect do
        expect(response).to have_status(500)
      end.to raise_error(/body: {"x":1,"error":{}}\nbacktrace:\na\nb/i)
    end
  end

  describe "have_json_body matcher" do
    it "fails if the response doesn't have a content type" do
      response = Rack::MockResponse.new(204, {}, "")

      expect do
        expect(response).to have_json_body
      end.to fail_with(/doesn't have a content-type/i)
    end

    it "fails if the response doesn't have an 'application/json' content type" do
      response = Rack::MockResponse.new(200, {"content-type" => "text/plain"}, "Stuff.")

      expect do
        expect(response).to have_json_body
      end.to fail_with(/content-type is/i)
    end

    it "fails if the response body doesn't contain valid JSON" do
      response = Rack::MockResponse.new(200, {"content-type" => "application/json"}, "<")

      expect do
        expect(response).to have_json_body
      end.to fail_with(/invalid JSON/i)
    end

    context "with no additional criteria" do
      it "passes for a valid JSON response" do
        response = Rack::MockResponse.new(200, {"content-type" => "application/json"}, "{}")

        expect do
          expect(response).to have_json_body
        end.to_not raise_error
      end
    end

    context "with a type specification" do
      let(:response) do
        Rack::MockResponse.new(200, {"content-type" => "application/json"}, "{}")
      end

      it "passes for a valid JSON response of the specified type" do
        expect do
          expect(response).to have_json_body(Object)
        end.to_not raise_error
      end

      it "fails for a valid JSON response of a different type" do
        expect do
          expect(response).to have_json_body(Array)
        end.to fail_with(/response body isn't a JSON Array/i)
      end
    end

    context "with a member specification" do
      let(:object_response) do
        Rack::MockResponse.new(
          200,
          {"content-type" => "application/json"},
          '{"message":"the message"}',
        )
      end
      let(:array_response) do
        Rack::MockResponse.new(
          200,
          {"content-type" => "application/json"},
          '["message"]',
        )
      end

      it "passes for a valid JSON Object response that includes the specified members" do
        expect do
          expect(object_response).to have_json_body.that_includes(:message)
        end.to_not raise_error
      end

      it "passes for a valid JSON Array response that includes the specified members" do
        expect do
          expect(array_response).to have_json_body.that_includes("message")
        end.to_not raise_error
      end

      it "fails for a valid JSON response that doesn't include the specified member" do
        expect do
          expect(object_response).to have_json_body.that_includes(:code)
        end.to fail_with(/to include :code/i)
      end

      it "passes for a valid JSON Object response that excludes the specified members" do
        expect do
          expect(object_response).to have_json_body.that_excludes(:other)
        end.to_not raise_error
      end

      it "passes for a valid JSON Array response that excludes the specified members" do
        expect do
          expect(array_response).to have_json_body.that_excludes("other")
        end.to_not raise_error
      end

      it "fails for a valid JSON response that doesn't exclude the specified member" do
        expect do
          expect(object_response).to have_json_body.that_excludes(:message)
        end.to fail_with(/not to include :message/i)
      end
    end

    context "with a length specification" do
      let(:object_response) do
        Rack::MockResponse.new(
          200,
          {"content-type" => "application/json"},
          '{"ebb":"nitzer", "chant":"join in the"}',
        )
      end
      let(:array_response) do
        Rack::MockResponse.new(
          200,
          {"content-type" => "application/json"},
          '["lies","gold","guns","fire","gold","judge","guns","fire"]',
        )
      end

      it "passes for a valid JSON Object response that has the specified number of members" do
        expect do
          expect(object_response).to have_json_body.of_length(2)
        end.to_not raise_error
      end

      it "passes for a valid JSON Array response that includes the specified members" do
        expect do
          expect(array_response).to have_json_body.of_length(8)
        end.to_not raise_error
      end

      it "fails for a valid JSON response that doesn't include the specified member" do
        expect do
          expect(array_response).to have_json_body.of_length(2)
        end.to fail_with(/length: 2/i)
      end
    end

    context "with a type and a member specification" do
      let(:object_response) do
        Rack::MockResponse.new(
          200,
          {"content-type" => "application/json"},
          '{"message":"the message"}',
        )
      end
      let(:array_response) do
        Rack::MockResponse.new(
          200,
          {"content-type" => "application/json"},
          '["message"]',
        )
      end

      it "passes for a valid JSON Object response that is of the correct type and includes " \
         "the specified members" do
        expect do
          expect(object_response).to have_json_body(Object).that_includes(:message)
        end.to_not raise_error
      end

      it "fails for a valid JSON response that includes the specified members " \
         "but is of a different type" do
        expect do
          expect(array_response).to have_json_body(Object).that_includes("message")
        end.to fail_with(/isn't a JSON Object/i)
      end

      it "fails for a valid JSON response that is of the correct type but doesn't include the specified members" do
        expect do
          expect(object_response).to have_json_body(Object).that_includes(:code)
        end.to fail_with(/to include :code/i)
      end
    end

    context "with a type and a length specification" do
      let(:object_response) do
        Rack::MockResponse.new(
          200,
          {"content-type" => "application/json"},
          '{"message":"the message","type":"the type"}',
        )
      end
      let(:array_response) do
        Rack::MockResponse.new(
          200,
          {"content-type" => "application/json"},
          '["message","type","brand"]',
        )
      end

      it "passes for a valid JSON Object response that is of the correct type and length" do
        expect do
          expect(object_response).to have_json_body(Object).of_length(2)
        end.to_not raise_error
      end

      it "fails for a valid JSON response that includes the specified length " \
         "but is of a different type" do
        expect do
          expect(array_response).to have_json_body(Object).of_length(2)
        end.to fail_with(/isn't a JSON Object/i)
      end

      it "fails for a valid JSON response that is of the correct type but a different length" do
        expect do
          expect(array_response).to have_json_body(Array).of_length(2)
        end.to fail_with(/length: 2/i)
      end
    end

    context "with additional expectations" do
      let(:object_response) do
        Rack::MockResponse.new(
          200,
          {"content-type" => "application/json"},
          '{"message":"the message", "massage":"Shiatsu", "messiah":"complex"}',
        )
      end
      let(:array_response) do
        Rack::MockResponse.new(
          200,
          {"content-type" => "application/json"},
          '["message", "note", "postage", "demiurge"]',
        )
      end

      it "passes for a valid JSON Object that matches all of them" do
        expect do
          expect(object_response).to have_json_body(Object).
            and(all(satisfy { |key, _val| key.length > 4 }))
        end.to_not raise_error
      end

      it "passes for a valid JSON Array that matches all of them" do
        expect do
          expect(array_response).to have_json_body(Array).
            and(all(be_a(String))).
            and(all(end_with("e")))
        end.to_not raise_error
      end

      it "fails for a valid JSON Object that doesn't match all of them" do
        expect do
          expect(object_response).to have_json_body(Object).
            and(all(satisfy { |key, _| key.length > 4 })).
            and(all(satisfy { |key, _| key.to_s.end_with?("e") }))
        end.to fail_with(/to all satisfy expression/)
      end

      it "fails for a valid JSON Array that doesn't match all of them" do
        expect do
          expect(array_response).to have_json_body(Array).
            and(all(be_a(String))).
            and(all(start_with("m")))
        end.to fail_with(/to all start with "m"/)
      end
    end
  end

  describe "last_response_json_body" do
    context "with a non-JSON response" do
      let(:last_response) { Rack::MockResponse.new(204, {}, "") }

      it "fails due to the have_json_body expectation first" do
        expect do
          expect(last_response_json_body[:title]).to eq("Ethel the Aardvark")
        end.to fail_with(/doesn't have a content-type/i)
      end
    end

    context "with a JSON response" do
      let(:last_response) do
        Rack::MockResponse.new(
          200,
          {"content-type" => "application/json"},
          '{"title":"Ethel the Aardvark"}',
        )
      end

      it "returns the JSON body if the inner expectation passes" do
        expect do
          expect(last_response_json_body[:title]).to eq("Ethel the Aardvark")
        end.to_not raise_error
      end

      it "fails if the outer expectation fails" do
        expect do
          expect(last_response_json_body).to be_empty
        end.to fail_with(/empty\?/)
      end
    end
  end
end
