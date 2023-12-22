# frozen_string_literal: true

require "webhookdb/spec_helpers"

module Webhookdb::SpecHelpers::Message
  def self.included(context)
    context.before(:each) do |example|
      if example.metadata[:messaging]
        Webhookdb::Message::Transport.override = :fake
        Webhookdb::Message::FakeTransport.reset!
      end
    end

    context.after(:each) do |example|
      if example.metadata[:messaging]
        Webhookdb::Message::Transport.override = nil
        Webhookdb::Message::FakeTransport.reset!
      end
    end

    super
  end

  # Retrieve the last sent email from the local mailpit service.
  module_function def fetch_last_email
    old = WebMock::Config.instance.allow
    mpurl = Webhookdb::Message::EmailTransport.mailpit_url
    getopts = {timeout: 5, logger: nil}
    WebMock::Config.instance.allow = mpurl
    begin
      list_resp = Webhookdb::Http.get("#{mpurl}/api/v1/messages", {limit: 1}, **getopts)
      msg = list_resp.parsed_response.fetch("messages").first
      msgid = msg.fetch("ID")
      headers_resp = Webhookdb::Http.get("#{mpurl}/api/v1/message/#{msgid}/headers", **getopts)
      msg["Headers"] = headers_resp.parsed_response
      return msg
    ensure
      WebMock::Config.instance.allow = old
    end
  end
end
