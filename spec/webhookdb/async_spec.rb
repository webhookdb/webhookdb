# frozen_string_literal: true

require "webhookdb/async"
require "webhookdb/async/job"
require "webhookdb/async/scheduled_job"

RSpec.describe "Webhookdb::Async", :async, :db do
  before(:all) do
    Webhookdb::Async.setup_tests
  end

  describe "audit logging" do
    let(:described_class) { Webhookdb::Async::AuditLogger }
    let(:noop_job) do
      Class.new do
        extend Webhookdb::Async::Job
        def _perform(*); end
      end
    end

    it "can eliminate large strings from the payload" do
      stub_const("Webhookdb::Async::AuditLogger::MAX_STR_LEN", 6)
      stub_const("Webhookdb::Async::AuditLogger::STR_PREFIX_LEN", 2)
      shortstr = "abcdef"
      longstr = "abcdefg"
      payload = {x: {y: {longarr: [shortstr, 1, longstr, 2], longhash: longstr, shorthash: shortstr}}}
      logs = capture_logs_from(described_class.logger, level: :info, formatter: :json) do
        expect do
          Amigo.publish("some.event", payload)
        end.to perform_async_job(noop_job)
      end
      expect(logs).to contain_exactly(
        include_json(
          "level" => "info",
          name: "Webhookdb::Async::AuditLogger",
          message: "async_job_audit",
          context: {
            event_id: be_a(String),
            event_name: "some.event",
            event_payload: [{x: {y: {longarr: ["abcdef", 1, "abc...", 2], longhash: "abc...", shorthash: "abcdef"}}}],
          },
        ),
      )
    end

    it "does not mutate the original payload" do
      stub_const("Webhookdb::Async::AuditLogger::MAX_STR_LEN", 6)
      stub_const("Webhookdb::Async::AuditLogger::STR_PREFIX_LEN", 2)
      shortstr = "abcdef"
      longstr = "abcdefg"
      payload = {x: {y: {longarr: [shortstr, 1, longstr, 2], longhash: longstr, shorthash: shortstr}}}
      event_json = Amigo::Event.create("x", [payload]).as_json
      orig_json = event_json.deep_dup
      Webhookdb::Async::AuditLogger.new.perform(event_json)
      expect(event_json).to eq(orig_json)
    end
  end
end
