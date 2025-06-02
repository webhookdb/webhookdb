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
      @old_config = Sidekiq.instance_variable_get(:@config)
      @config = Sidekiq::DEFAULTS.dup
      Sidekiq.instance_variable_set(:@config, @config)
    end

    after(:each) do
      described_class.reset_configuration
      Sidekiq.instance_variable_set(:@config, @old_config)
      Sidekiq.instance_variable_set(:@client_chain, Sidekiq::Middleware::Chain.new(Sidekiq))
      Sidekiq.instance_variable_set(:@server_chain, Sidekiq::Middleware::Chain.new(Sidekiq))
      described_class.run_after_configured_hooks
    end

    it "can configure the client" do
      described_class._configure_client(Sidekiq, {url: "redis://x"})
      expect(Sidekiq.client_middleware.entries).to include(
        have_attributes(klass: Amigo::DurableJob::ClientMiddleware),
      )
    end

    it "can configure the server" do
      described_class._configure_server(Sidekiq, {url: "redis://x"})
      expect(Sidekiq.server_middleware.entries).to include(
        have_attributes(klass: Amigo::JobInContext::ServerMiddleware),
      )
    end

    it "turns off SSL verify on Heroku" do
      described_class.sidekiq_redis_url = "rediss://x"

      described_class.run_after_configured_hooks
      Sidekiq.redis do |r|
        expect(r.instance_variable_get(:@options)).to_not include(:ssl_params)
      end

      ENV["HEROKU_APP_ID"] = "z"
      described_class.run_after_configured_hooks
      Sidekiq.redis do |r|
        expect(r.instance_variable_get(:@options)).to include(:ssl_params)
      end
    ensure
      ENV.delete("HEROKU_APP_ID")
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
end
