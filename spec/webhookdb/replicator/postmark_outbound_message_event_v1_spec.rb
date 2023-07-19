# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::PostmarkOutboundMessageEventV1, :db do
  bounce_json = JSON.parse(<<~J)
    {
      "RecordType": "Bounce",
      "MessageStream": "outbound",
      "ID": 4323372036854775807,
      "Type": "HardBounce",
      "TypeCode": 1,
      "Name": "Hard bounce",
      "Tag": "Test",
      "MessageID": "883953f4-6105-42a2-a16a-77a8eac79483",
      "Metadata" : {
        "a_key" : "a_value",
        "b_key": "b_value"
       },
      "ServerID": 23,
      "Description": "The server was unable to deliver your message (ex: unknown user, mailbox not found).",
      "Details": "Test bounce details",
      "Email": "john@example.com",
      "From": "sender@example.com",
      "BouncedAt": "2019-11-05T16:33:54.9070259Z",
      "DumpAvailable": true,
      "Inactive": true,
      "CanActivate": true,
      "Subject": "Test subject",
      "Content": "<Full dump of bounce>"
    }
  J
  open_json = JSON.parse(<<~J)
    {
      "RecordType": "Open",
      "MessageStream": "outbound",
      "FirstOpen": true,
      "Client": {
        "Name": "Chrome 35.0.1916.153",
        "Company": "Google",
        "Family": "Chrome"
      },
      "OS": {
        "Name": "OS X 10.7 Lion",
        "Company": "Apple Computer, Inc.",
        "Family": "OS X 10"
      },
      "Platform": "WebMail",
      "UserAgent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/35.0.1916.153 Safari/537.36",
      "Geo": {
        "CountryISOCode": "RS",
        "Country": "Serbia",
        "RegionISOCode": "VO",
        "Region": "Autonomna Pokrajina Vojvodina",
        "City": "Novi Sad",
        "Zip": "21000",
        "Coords": "45.2517,19.8369",
        "IP": "188.2.95.4"
      },
      "MessageID": "883953f4-6105-42a2-a16a-77a8eac79483",
      "Metadata" : {
        "a_key" : "a_value",
        "b_key": "b_value"
       },
      "ReceivedAt": "2019-11-05T16:33:54.9070259Z",
      "Tag": "welcome-email",
      "Recipient": "john@example.com"
    }
  J
  delivery_json = JSON.parse(<<~J)
    {
      "MessageID": "883953f4-6105-42a2-a16a-77a8eac79483",
      "Recipient": "john@example.com",
      "DeliveredAt": "2019-11-05T16:33:54.9070259Z",
      "Details": "Test delivery webhook details",
      "Tag": "welcome-email",
      "ServerID": 23,
      "Metadata" : {
        "a_key" : "a_value",
        "b_key": "b_value"
       },
      "RecordType": "Delivery",
      "MessageStream":"outbound"
    }
  J
  click_json = JSON.parse(<<~J)
    {
      "RecordType": "Click",
      "MessageStream": "outbound",
      "ClickLocation": "HTML",
      "Client": {
        "Name": "Chrome 35.0.1916.153",
        "Company": "Google",
        "Family": "Chrome"
      },
      "OS": {
        "Name": "OS X 10.7 Lion",
        "Company": "Apple Computer, Inc.",
        "Family": "OS X 10"
      },
      "Platform": "Desktop",
      "UserAgent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/35.0.1916.153 Safari/537.36",
      "OriginalLink": "https://example.com",
      "Geo": {
        "CountryISOCode": "RS",
        "Country": "Serbia",
        "RegionISOCode": "VO",
        "Region": "Autonomna Pokrajina Vojvodina",
        "City": "Novi Sad",
        "Zip": "21000",
        "Coords": "45.2517,19.8369",
        "IP": "8.8.8.8"
      },
      "MessageID": "00000000-0000-0000-0000-000000000000",
      "Metadata" : {
        "a_key" : "a_value",
        "b_key": "b_value"
       },
      "ReceivedAt": "2017-10-25T15:21:11.9065619Z",
      "Tag": "welcome-email",
      "Recipient": "john@example.com"
    }
  J
  spam_complaint_json = JSON.parse(<<~J)
    {
      "RecordType": "SpamComplaint",
      "MessageStream": "outbound",
      "ID": 42,
      "Type": "SpamComplaint",
      "TypeCode": 512,
      "Name": "Spam complaint",
      "Tag": "Test",
      "MessageID": "00000000-0000-0000-0000-000000000000",
      "Metadata" : {
        "a_key" : "a_value",
        "b_key": "b_value"
       },
      "ServerID": 1234,
      "Description": "",
      "Details": "Test spam complaint details",
      "Email": "john@example.com",
      "From": "sender@example.com",
      "BouncedAt": "2019-11-05T16:33:54.9070259Z",
      "DumpAvailable": true,
      "Inactive": true,
      "CanActivate": false,
      "Subject": "Test subject",
      "Content": "<Abuse report dump>"
    }
  J
  subscription_change_json = JSON.parse(<<~J)
    {
      "RecordType":"SubscriptionChange",
      "MessageID": "883953f4-6105-42a2-a16a-77a8eac79483",
      "ServerID":123456,
      "MessageStream": "outbound",
      "ChangedAt": "2020-02-01T10:53:34.416071Z",
      "Recipient": "bounced-address@wildbit.com",
      "Origin": "Recipient",
      "SuppressSending": true,
      "SuppressionReason": "HardBounce",
      "Tag": "my-tag",
      "Metadata": {
        "example": "value",
        "example_2": "value"
      }
    }
  J
  events =     [
    ["bounce", bounce_json, "BouncedAt"],
    ["open", open_json, "ReceivedAt"],
    ["delivery", delivery_json, "DeliveredAt"],
    ["click", click_json, "ReceivedAt"],
    ["spam_compliant", spam_complaint_json, "BouncedAt"],
    ["subscription_change", subscription_change_json, "ChangedAt"],
  ]

  events.each do |(name, bod, _tsfield)|
    describe name do
      it_behaves_like "a replicator", "postmark_outbound_message_event_v1" do
        let(:body) { bod }
        let(:expected_data) { bod }
      end
    end
  end

  describe "webhook validation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "postmark_outbound_message_event_v1") }
    let(:svc) { Webhookdb::Replicator.create(sint) }

    it "returns 202 if the remote addr is valid" do
      req = fake_request
      req.add_header("REMOTE_ADDR", Webhookdb::Postmark.allowed_ips.sample)
      status, _headers, _body = svc.webhook_response(req).to_rack
      expect(status).to eq(202)
    end

    it "returns 202 if x-forwarded-for is valid" do
      req = fake_request
      req.add_header("HTTP_X_FORWARDED_FOR", Webhookdb::Postmark.allowed_ips.sample)
      status, _headers, _body = svc.webhook_response(req).to_rack
      expect(status).to eq(202)
    end

    it "returns 401 if neither ip is valid" do
      req = fake_request
      req.add_header("REMOTE_ADDR", "1.1.1.1")
      req.add_header("HTTP_X_FORWARDED_FOR", "1.1.1.1")
      status, _headers, _body = svc.webhook_response(req).to_rack
      expect(status).to eq(401)
    end
  end

  describe "state machine calculation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "postmark_outbound_message_event_v1") }
    let(:svc) { Webhookdb::Replicator.create(sint) }

    describe "calculate_webhook_state_machine" do
      it "prompts with instructions" do
        sm = sint.replicator.calculate_webhook_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: "Press Enter after Saved Changes succeeds:",
          prompt_is_secret: false,
          post_to_url: end_with("/transition/noop_create"),
          complete: false,
          output: match("You are about to set up webhooks for Postmark Outbound Message Events"),
        )
      end

      it "says all set once webhook secret is set" do
        sint.webhook_secret = "foo"
        sm = sint.replicator.calculate_webhook_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          prompt: "",
          prompt_is_secret: false,
          post_to_url: "",
          complete: true,
          output: match("Events will be synced as they come in."),
        )
      end
    end
  end
end
