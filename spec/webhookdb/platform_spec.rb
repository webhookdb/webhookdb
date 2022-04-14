# frozen_string_literal: true

require "webhookdb/platform"

RSpec.describe Webhookdb::Platform, :db do
  # rubocop:disable Layout/LineLength
  cli_mac_ua = "WebhookDB/v1 webhookdb-cli/abcd1234 (darwin; arm64) Built/1970-01-01T00:00:00Z https://webhookdb.com"
  cli_js_ua = "WebhookDB/v1 webhookdb-cli/abcd1234 (js; wasm) Built/1970-01-01T00:00:00Z https://webhookdb.com"
  web_mac_ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.102 Safari/537.36"
  web_linux_ua = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/44.0.2403.157 Safari/537.36"
  # rubocop:enable Layout/LineLength

  describe "platform_user_agent" do
    it "returns the platform UA if set" do
      env = {
        "HTTP_WHDB_USER_AGENT" => cli_js_ua,
        "HTTP_WHDB_PLATFORM_USER_AGENT" => web_mac_ua,
      }
      expect(described_class.platform_user_agent(env)).to eq(web_mac_ua)

      env = {
        "HTTP_USER_AGENT" => web_linux_ua,
      }
      expect(described_class.platform_user_agent(env)).to eq("")
    end
  end

  describe "user_agent" do
    it "returns the preferred UA (custom header, normal header)" do
      env = {
        "HTTP_USER_AGENT" => web_linux_ua,
        "HTTP_WHDB_USER_AGENT" => cli_js_ua,
        "HTTP_WHDB_PLATFORM_USER_AGENT" => web_mac_ua,
      }
      expect(described_class.user_agent(env)).to eq(web_mac_ua)

      env = {
        "HTTP_USER_AGENT" => web_linux_ua,
        "HTTP_WHDB_USER_AGENT" => cli_js_ua,
      }
      expect(described_class.user_agent(env)).to eq(cli_js_ua)

      env = {
        "HTTP_USER_AGENT" => web_linux_ua,
      }
      expect(described_class.user_agent(env)).to eq(web_linux_ua)

      env = {}
      expect(described_class.user_agent(env)).to eq("")
    end
  end

  describe "shortcut_ctrlc" do
    it "parses the platform user agent if given (Mac)" do
      env = {
        "HTTP_USER_AGENT" => web_linux_ua,
        "HTTP_WHDB_USER_AGENT" => cli_js_ua,
        "HTTP_WHDB_PLATFORM_USER_AGENT" => web_mac_ua,
      }
      sc = described_class.shortcut_ctrlc(env)
      expect(sc).to eq("Cmd+C")
    end

    it "parses the cli user agent (Mac)" do
      env = {
        "HTTP_USER_AGENT" => web_linux_ua,
        "HTTP_WHDB_USER_AGENT" => cli_mac_ua,
      }
      sc = described_class.shortcut_ctrlc(env)
      expect(sc).to eq("Cmd+C")
    end

    it "parses the default user agent (Mac)" do
      env = {
        "HTTP_USER_AGENT" => web_mac_ua,
      }
      sc = described_class.shortcut_ctrlc(env)
      expect(sc).to eq("Cmd+C")
    end

    it "falls back to Ctrl if not mac" do
      env = {
        "HTTP_USER_AGENT" => web_linux_ua,
      }
      sc = described_class.shortcut_ctrlc(env)
      expect(sc).to eq("Ctrl+C")
    end
  end
end
