# frozen_string_literal: true

require "webhookdb/async"
require "webhookdb/async/job"
require "webhookdb/async/scheduled_job"

RSpec.describe "Webhookdb::Async", :async, :db do
  let(:described_class) { Webhookdb::Async }

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

  describe "Sidekiq" do
    before(:each) do
      @old_config = Sidekiq.default_configuration
      @config = Sidekiq::Config.new
      Sidekiq.instance_variable_set(:@config, @config)
    end

    after(:each) do
      described_class.reset_configuration
      Sidekiq.instance_variable_set(:@config, @old_config)
      described_class.run_after_configured_hooks
    end

    it "can configure the client" do
      cfg = Sidekiq::Config.new
      described_class._configure_client(cfg)
      expect(cfg.client_middleware.entries).to include(
        have_attributes(klass: Amigo::DurableJob::ClientMiddleware),
      )
    end

    it "can configure the server" do
      cfg = Sidekiq::Config.new
      described_class._configure_server(cfg)
      expect(cfg.server_middleware.entries).to include(
        have_attributes(klass: Amigo::JobInContext::ServerMiddleware),
      )
    end
  end

  describe "open_web" do
    it "opens a browser" do
      expect(described_class).to receive(:`).with(%r{open http://.+:.+@localhost:18001/sidekiq})
      described_class.open_web
    end
  end

  describe "setup method calls" do
    it "requires jobs when setup_web is called" do
      Amigo.structured_logging = false # Reset so we can call another #setup
      expect(Amigo).to receive(:install_amigo_jobs)
      expect(Amigo).to_not receive(:start_scheduler)
      described_class.setup_web
    end

    it "starts the scheduler when setup_workers is called" do
      Amigo.structured_logging = false # Reset so we can call another #setup
      expect(Amigo).to receive(:install_amigo_jobs)
      expect(Amigo).to receive(:start_scheduler)
      described_class.setup_workers
    end
  end

  describe "SpecHelpers", sidekiq: :fake do
    cls = Class.new do
      include Sidekiq::Worker
    end

    describe "have_empty_queues" do
      it "succeeds if queues are empty" do
        expect(Sidekiq).to have_empty_queues
        cls.perform_async
        expect { expect(Sidekiq).to have_empty_queues }.to raise_error(/Sidekiq queues have jobs:/)
      end
    end
  end
end
