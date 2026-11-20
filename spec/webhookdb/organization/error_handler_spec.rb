# frozen_string_literal: true

require "webhookdb/messages/specs"

RSpec.describe Webhookdb::Organization::ErrorHandler, :db do
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:sint) { Webhookdb::Fixtures.service_integration.create(organization: org, table_name: "fake_v1_1452") }

  let(:tmpl) do
    tmpl = Webhookdb::Messages::Testers::Basic.new
    tmpl.define_singleton_method(:signature) { "tester" }
    si = sint
    tmpl.define_singleton_method(:service_integration) { si }
    tmpl
  end

  describe "payload_for_template" do
    it "returns the expected payload" do
      eh = Webhookdb::Fixtures.organization_error_handler(organization: org).create
      p = eh.payload_for_template(tmpl)
      expect(p).to eq(
        {
          details: {
            api_url: "http://localhost:18001",
            docs_url: "https://docs.webhookdb.com",
            oss_repo: "https://github.com/webhookdb/webhookdb",
            support_email: "hello@webhookdb.com",
          },
          error_type: "basic",
          message: "email to hello@webhookdb.com",
          organization_key: org.key,
          service_integration_id: sint.opaque_id,
          service_integration_name: sint.service_name,
          service_integration_table: sint.table_name,
          signature: "tester",
        },
      )
    end
  end

  describe "dispatch" do
    it "POSTS to the configured url with the payload" do
      eh = Webhookdb::Fixtures.organization_error_handler.create(url: "https://fake.webhookdb.com/error")
      req = stub_request(:post, "https://fake.webhookdb.com/error").
        with(body: "{\"x\":1}").
        to_return(status: 200, body: "", headers: {})
      eh.dispatch({x: 1})
      expect(req).to have_been_made
    end

    it "calls Sentry if the URL is a Sentry DSN" do
      eh = Webhookdb::Fixtures.organization_error_handler.create(url: "https://public:private@abc.ingest.sentry.io/1")
      payload = eh.payload_for_template(tmpl)
      expect(Uuidx).to receive(:v4).and_return("a7eb3ee9-2ace-47cd-a18c-a33a3bc5e1b4")
      # rubocop:disable Layout/LineLength
      req = stub_request(:post, "https://abc.ingest.sentry.io/api/1/envelope/").
        with(
          body: '{"event_id":"a7eb3ee9-2ace-47cd-a18c-a33a3bc5e1b4","sent_at":"2025-01-07T20:30:15Z"}
{"type":"event","content_type":"application/json"}
{"event_id":"a7eb3ee9-2ace-47cd-a18c-a33a3bc5e1b4","timestamp":"2025-01-07T20:30:15Z","platform":"ruby","level":"warning","transaction":"fake_v1_1452","release":"webhookdb@unknown-release","environment":"test","tags":{},"extra":{"api_url":"http://localhost:18001","support_email":"hello@webhookdb.com","oss_repo":"https://github.com/webhookdb/webhookdb","docs_url":"https://docs.webhookdb.com"},"fingerprint":["tester"],"message":"WebhookDB Error in fake_v1\n\nemail to hello@webhookdb.com"}',
          headers: {
            "X-Sentry-Auth" => "Sentry sentry_version=7, sentry_key=public, sentry_client=sentry-ruby/5.22.1, sentry_timestamp=1736281815",
          },
        ).
        to_return(status: 200, body: "", headers: {})
      # rubocop:enable Layout/LineLength
      Timecop.freeze(Time.at(1_736_281_815)) do
        eh.dispatch(payload)
      end
      expect(req).to have_been_made
    end

    it "calls Sentry if the URL uses a 'sentry' protocol" do
      eh = Webhookdb::Fixtures.organization_error_handler.create(url: "sentry://public@sentry.example.com/123")
      payload = eh.payload_for_template(tmpl)
      req = stub_request(:post, "https://sentry.example.com/api/123/envelope/").
        to_return(status: 200, body: "", headers: {})
      Timecop.freeze(Time.at(1_736_281_815)) do
        eh.dispatch(payload)
      end
      expect(req).to have_been_made
    end

    it "adheres to the code explanation of how a Sentry payload is converted" do
      eh = Webhookdb::Fixtures.organization_error_handler.create(url: "https://public@sentry.io/1?level=error")
      tmpl.define_singleton_method(:liquid_drops) do
        {
          shortstr: "shortstring",
          longstr: "x" * 201,
          jsonstr: '{"x":1}',
          spacestr: "space str",
          num: 5,
        }
      end
      payload = eh.payload_for_template(tmpl)
      expect(Uuidx).to receive(:v4).and_return("a7eb3ee9-2ace-47cd-a18c-a33a3bc5e1b4")
      # rubocop:disable Layout/LineLength
      req = stub_request(:post, "https://sentry.io/api/1/envelope/").
        with(
          body: '{"event_id":"a7eb3ee9-2ace-47cd-a18c-a33a3bc5e1b4","sent_at":"2025-01-07T20:30:15Z"}
{"type":"event","content_type":"application/json"}
{"event_id":"a7eb3ee9-2ace-47cd-a18c-a33a3bc5e1b4","timestamp":"2025-01-07T20:30:15Z","platform":"ruby","level":"error","transaction":"fake_v1_1452","release":"webhookdb@unknown-release","environment":"test","tags":{"shortstr":"shortstring","num":5},"extra":{"longstr":"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx","jsonstr":"{\"x\":1}","spacestr":"space str"},"fingerprint":["tester"],"message":"WebhookDB Error in fake_v1\n\nemail to hello@webhookdb.com"}',
        ).
        to_return(status: 200, body: "", headers: {})
      # rubocop:enable Layout/LineLength
      Timecop.freeze(Time.at(1_736_281_815)) do
        eh.dispatch(payload)
      end
      expect(req).to have_been_made
    end
  end
end
