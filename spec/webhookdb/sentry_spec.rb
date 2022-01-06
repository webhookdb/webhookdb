# frozen_string_literal: true

require "appydays/loggable"

require "webhookdb/sentry"

RSpec.describe Webhookdb::Sentry do
  after(:each) do
    described_class.reset_configuration
  end

  it "configures the Sentry service" do
    described_class.dsn = "http://public:secret@not-really-sentry.nope/someproject"
    described_class.run_after_configured_hooks
    client = Sentry.get_current_client
    expect(client).to_not be_nil
    expect(client.configuration).to have_attributes(
      logger: Webhookdb::Sentry.logger,
      dsn: have_attributes(
        server: "http://not-really-sentry.nope",
        public_key: "public",
        secret_key: "secret",
        project_id: "someproject",
      ),
    )
  end

  it "can unconfigure Sentry" do
    described_class.dsn = "http://public:secret@not-really-sentry.nope/someproject"
    described_class.run_after_configured_hooks
    expect(Sentry).to be_initialized
    described_class.dsn = ""
    described_class.run_after_configured_hooks
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
end
