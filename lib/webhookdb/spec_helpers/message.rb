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

  module_function def stub_email_post(opts={})
    opts[:with] ||= {}
    opts[:fixture] ||= "postmark/mail_send"
    opts[:message_id] ||= "aaa-bbb-ccc"
    opts[:status] ||= 200

    body = load_fixture_data(opts[:fixture])
    body["MessageID"] = opts[:message_id]

    req = stub_request(:post, "https://api.postmarkapp.com/email")
    (req = req.with(opts[:with])) if opts[:with].present?
    req = req.to_return(
      status: opts[:status],
      body: body.to_json,
      headers: opts[:headers],
    )
    return req
  end

  module_function def stub_twilio_sms(opts={})
    opts[:fixture] ||= "twilio/send_message"
    opts[:sid] ||= "SMABCDXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    opts[:status] ||= 200

    body = load_fixture_data(opts[:fixture])
    body["sid"] = opts[:sid]

    req = stub_request(:post, "https://api.twilio.com/2010-04-01/Accounts/AC444test/Messages.json")
    req = req.to_return(
      status: opts[:status],
      body: body.to_json,
      headers: opts[:headers],
    )
    return req
  end
end
