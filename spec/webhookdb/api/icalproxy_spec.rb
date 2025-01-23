# frozen_string_literal: true

require "webhookdb/api/icalproxy"

RSpec.describe Webhookdb::API::Icalproxy, :async, :db do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }

  describe "POST /v1/stripe/icalproxy", reset_configuration: Webhookdb::Icalendar do
    before(:each) do
      Webhookdb::Icalendar.proxy_api_key = "mykey"
    end

    it "errors if no api key is configured" do
      Webhookdb::Icalendar.proxy_api_key = ""
      header "Authorization", "Apikey mykey"

      post "/v1/icalproxy/webhook", {urls: ["abc"]}
      expect(last_response).to have_status(402)
    end

    it "errors for a missing auth header" do
      post "/v1/icalproxy/webhook", {urls: ["abc"]}
      expect(last_response).to have_status(401)
    end

    it "errors for a bad auth header" do
      header "Authorization", "Apikey nope"
      post "/v1/icalproxy/webhook", {urls: ["abc"]}
      expect(last_response).to have_status(401)
    end

    it "enqueues an async job with the given urls", sidekiq: :fake do
      header "Authorization", "Apikey mykey"

      post "/v1/icalproxy/webhook", {urls: ["abc", "xyz"]}
      expect(last_response).to have_status(202)

      expect(Sidekiq).to have_queue("default").consisting_of(
        job_hash(
          Webhookdb::Jobs::IcalendarEnqueueSyncsForUrls,
          args: [["abc", "xyz"]],
        ),
      )
    end
  end
end
