# frozen_string_literal: true

require "webhookdb/slack"

RSpec.describe "Webhookdb::Slack" do
  let(:described_class) { Webhookdb::Slack }

  describe "new_notifier" do
    before(:each) do
      described_class.http_client = nil
      @suppress_all = described_class.suppress_all
      described_class.suppress_all = false
    end

    after(:each) do
      described_class.http_client = nil
      described_class.suppress_all = @suppress_all
    end

    it "does not set the notifier http client unless one is configured" do
      n = described_class.new_notifier
      expect(n.config.http_client).to be Slack::Notifier::Util::HTTPClient
    end

    it "sets the notifier http client if one is configured" do
      client = described_class::NoOpHttpClient.new
      described_class.http_client = client

      n = described_class.new_notifier
      expect(n.config.http_client).to be client
    end

    it "sets the http client to a noop client if supress is configured" do
      described_class.suppress_all = true
      n = described_class.new_notifier
      expect(n.config.http_client).to be_a(described_class::NoOpHttpClient)
    end
  end
end
