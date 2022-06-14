# frozen_string_literal: true

require "webhookdb/slack"

RSpec.describe Webhookdb::Slack do
  before(:each) do
    described_class.http_client = nil
    described_class.reset_configuration
  end

  after(:each) do
    described_class.reset_configuration
    described_class.http_client = nil
  end

  describe "new_notifier" do
    before(:each) do
      described_class.suppress_all = false
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

    it "is set with default fields" do
      stub_request(:post, "http://unconfigured-slack-webhook/").
        with(
          body: {"payload" => '{"channel":"#eng-naboo","username":"Unknown","icon_emoji":":question:","text":"hello"}'},
        ).
        to_return(status: 200, body: "", headers: {})

      n = described_class.new_notifier
      n.post(text: "hello")
    end

    it "is set with explicit fields" do
      stub_request(:post, "http://unconfigured-slack-webhook/").
        with(
          body: {"payload" => '{"channel":"#foo","username":"U","icon_emoji":":h:","text":"hello"}'},
        ).
        to_return(status: 200, body: "", headers: {})

      n = described_class.new_notifier(channel: "#foo", username: "U", icon_emoji: ":h:")
      n.post(text: "hello")
    end

    it "can use a channel override" do
      described_class.channel_override = "#testfake"
      stub_request(:post, "http://unconfigured-slack-webhook/").
        with(
          body: {"payload" => '{"channel":"#testfake","username":"Unknown","icon_emoji":":question:","text":"hello"}'},
        ).
        to_return(status: 200, body: "", headers: {})
      n = described_class.new_notifier
      n.post(text: "hello")
    end

    it "can override the override" do
      described_class.channel_override = "#testfake"
      stub_request(:post, "http://unconfigured-slack-webhook/").
        with(
          body: {"payload" => '{"channel":"#forced","username":"Unknown","icon_emoji":":question:","text":"hello"}'},
        ).
        to_return(status: 200, body: "", headers: {})

      n = described_class.new_notifier(force_channel: "#forced")
      n.post(text: "hello")
    end
  end
end
