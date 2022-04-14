# frozen_string_literal: true

module Webhookdb::Platform
  PLATFORM_USER_AGENT_HTTP = "HTTP_WHDB_PLATFORM_USER_AGENT"
  CLI_USER_AGENT_HTTP = "HTTP_WHDB_USER_AGENT"
  USER_AGENT_HTTP = "HTTP_USER_AGENT"
  HEADERS = [
    PLATFORM_USER_AGENT_HTTP,
    CLI_USER_AGENT_HTTP,
    USER_AGENT_HTTP,
  ].freeze

  # Return the value of the platform UA header.
  # For WASM, this is the browser's user agent.
  # For a binary, this is empty.
  def self.platform_user_agent(env)
    return env[PLATFORM_USER_AGENT_HTTP] || ""
  end

  # Return the user agent in the env.
  # This should be the CLI user agent,
  # though it may also be a browser in WASM depending on the browser.
  def self.user_agent(env)
    values = HEADERS.map { |h| env[h] }
    return values.find(&:present?) || ""
  end
end
