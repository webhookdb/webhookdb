# frozen_string_literal: true

require "appydays/loggable"

require "webhookdb/sentry"

RSpec.describe Webhookdb::Sentry do
  after(:each) do
    described_class.reset_configuration
  end

  it "configures the Sentry service" do
    described_class.reset_configuration(dsn: "http://public:secret@not-really-sentry.nope/someproject")
    client = Sentry.get_current_client
    expect(client).to_not be_nil
    expect(client.configuration).to have_attributes(
      sdk_logger: described_class.logger,
      dsn: have_attributes(
        server: "http://not-really-sentry.nope",
        public_key: "public",
        secret_key: "secret",
        project_id: "someproject",
      ),
    )
  end

  it "can unconfigure Sentry" do
    described_class.reset_configuration(dsn: "http://public:secret@not-really-sentry.nope/someproject")
    expect(Sentry).to be_initialized
    described_class.reset_configuration(dsn: "")
    expect(Sentry).to_not be_initialized
  end

  describe "enabled?" do
    it "returns true if DSN is set" do
      described_class.dsn = "foo"
      expect(described_class).to be_enabled
    end

    it "returns false if DSN is not set" do
      described_class.dsn = ""
      expect(described_class).to_not be_enabled
    end
  end

  describe "trace sampling" do
    let(:dsn) { "http://public:secret@not-really-sentry.nope/someproject" }

    before(:each) do
      described_class.reset_configuration(
        traces_base_sample_rate: 0.5,
        traces_web_sample_rate: 0.1,
        traces_web_load_sample_rate: 0.01,
        traces_job_sample_rate: 0.1,
        traces_job_load_sample_rate: 0.01,
      )
    end

    it "configures the trace sampler unless traces_base_sample_rate is 0" do
      described_class.reset_configuration(dsn:, traces_base_sample_rate: 0)
      expect(Sentry.configuration.traces_sample_rate).to eq(0)
      expect(Sentry.configuration.traces_sampler).to be_nil
      described_class.reset_configuration(dsn:, traces_base_sample_rate: 0.5)
      expect(Sentry.configuration.traces_sample_rate).to be_nil
      expect(Sentry.configuration.traces_sampler).to_not be_nil
    end

    it "uses the parent decision if available" do
      ctx = {parent_sampled: 0.8}
      expect(described_class.traces_sampler(ctx)).to eq(0.8)
      ctx = {parent_sampled: false}
      expect(described_class.traces_sampler(ctx)).to be(false)
      ctx = {parent_sampled: nil}
      expect(described_class.traces_sampler(ctx)).to be(0.5)
      ctx = {}
      expect(described_class.traces_sampler(ctx)).to be(0.5)
    end

    it "uses the baseline by default" do
      ctx = {transaction_context: {}}
      expect(described_class.traces_sampler(ctx)).to eq(0.5)
    end

    it "skips certain ops" do
      ctx = {parent_sampled: 0.8, transaction_context: {op: "queue.publish"}}
      expect(described_class.traces_sampler(ctx)).to eq(0.0)
    end

    describe "for web requests" do
      it "uses the web sample rate by default" do
        ctx = {transaction_context: {op: "http.server", name: "/foo"}}
        expect(described_class.traces_sampler(ctx)).to eq(0.05)
      end

      it "ignores sink calls" do
        ctx = {transaction_context: {op: "http.server", name: "/sink"}}
        expect(described_class.traces_sampler(ctx)).to eq(0)
      end

      it "biases healthcheck down from the load rate" do
        ctx = {transaction_context: {op: "http.server", name: "/healthz"}}
        expect(described_class.traces_sampler(ctx)).to eq(0.0005)
      end

      it "uses the load rate for certain endpoints" do
        ctx = {transaction_context: {op: "http.server", name: "/v1/service_integrations/svi_12abc"}}
        expect(described_class.traces_sampler(ctx)).to eq(0.005)
      end
    end

    describe "for jobs" do
      it "uses the job sample rate by default" do
        ctx = {transaction_context: {op: "queue.process", name: "Sidekiq/Webhookdb::Jobs::Xyz"}}
        expect(described_class.traces_sampler(ctx)).to eq(0.05)
      end

      it "uses the load rate for certain jobs" do
        ctx = {transaction_context: {op: "queue.process", name: "Sidekiq/Webhookdb::Jobs::ProcessWebhook"}}
        expect(described_class.traces_sampler(ctx)).to eq(0.005)
      end
    end
  end
end
