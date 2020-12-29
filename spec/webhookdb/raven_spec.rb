# frozen_string_literal: true

require "appydays/loggable"

require "webhookdb/raven"

RSpec.describe Webhookdb::Raven do
  after(:each) do
    described_class.reset_configuration
  end

  it "configures the Raven service" do
    described_class.dsn = "http://public:secret@not-really-sentry.nope/someproject"
    described_class.run_after_configured_hooks
    expect(Raven.configuration.server).to eq("http://not-really-sentry.nope")
    expect(Raven.configuration.public_key).to eq("public")
    expect(Raven.configuration.secret_key).to eq("secret")
    expect(Raven.configuration.project_id).to eq("someproject")
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
