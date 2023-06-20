# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::PostmarkInboundMessageV1, :db do
  let(:bod) do
    JSON.parse(<<~J)
      {
        "FromName": "Postmarkapp Support",
        "MessageStream": "inbound",
        "From": "support@postmarkapp.com",
        "FromFull": {
          "Email": "support@postmarkapp.com",
          "Name": "Postmarkapp Support",
          "MailboxHash": ""
        },
        "To": "\\"Firstname Lastname\\" <yourhash+SampleHash@inbound.postmarkapp.com>",
        "ToFull": [
          {
            "Email": "yourhash+SampleHash@inbound.postmarkapp.com",
            "Name": "Firstname Lastname",
            "MailboxHash": "SampleHash"
          }
        ],
        "Cc": "\\"First Cc\\" <firstcc@postmarkapp.com>, secondCc@postmarkapp.com>",
        "CcFull": [
          {
            "Email": "firstcc@postmarkapp.com",
            "Name": "First Cc",
            "MailboxHash": ""
          },
          {
            "Email": "secondCc@postmarkapp.com",
            "Name": "",
            "MailboxHash": ""
          }
        ],
        "Bcc": "\\"First Bcc\\" <firstbcc@postmarkapp.com>, secondbcc@postmarkapp.com>",
        "BccFull": [
          {
            "Email": "firstbcc@postmarkapp.com",
            "Name": "First Bcc",
            "MailboxHash": ""
          },
          {
            "Email": "secondbcc@postmarkapp.com",
            "Name": "",
            "MailboxHash": ""
          }
        ],
        "OriginalRecipient": "yourhash+SampleHash@inbound.postmarkapp.com",
        "Subject": "Test subject",
        "MessageID": "73e6d360-66eb-11e1-8e72-a8904824019b",
        "ReplyTo": "replyto@postmarkapp.com",
        "MailboxHash": "SampleHash",
        "Date": "Fri, 1 Aug 2014 16:45:32 -04:00",
        "TextBody": "This is a test text body.",
        "HtmlBody": "<html><body><p>This is a test html body.</p></body></html>",
        "StrippedTextReply": "This is the reply text",
        "Tag": "TestTag",
        "Headers": [
          {
            "Name": "X-Header-Test",
            "Value": ""
          },
          {
            "Name": "X-Spam-Status",
            "Value": "No"
          },
          {
            "Name": "X-Spam-Score",
            "Value": "-0.1"
          },
          {
            "Name": "X-Spam-Tests",
            "Value": "DKIM_SIGNED,DKIM_VALID,DKIM_VALID_AU,SPF_PASS"
          }
        ],
        "Attachments": [
          {
            "Name": "test.txt",
            "Content": "VGhpcyBpcyBhdHRhY2htZW50IGNvbnRlbnRzLCBiYXNlLTY0IGVuY29kZWQu",
            "ContentType": "text/plain",
            "ContentLength": 45
          }
        ]
      }
    J
  end

  it_behaves_like "a replicator", "postmark_inbound_message_v1" do
    let(:body) { bod }
    let(:expected_data) { bod }
  end

  describe "webhook validation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "postmark_inbound_message_v1") }
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
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "postmark_inbound_message_v1") }
    let(:svc) { Webhookdb::Replicator.create(sint) }

    describe "calculate_create_state_machine" do
      it "prompts with instructions" do
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: "Press Enter after Save Webhook succeeds:",
          prompt_is_secret: false,
          post_to_url: end_with("/transition/noop_create"),
          complete: false,
          output: match("You are about to set up webhooks for Postmark Inbound Messages"),
        )
      end

      it "says all set once webhook secret is set" do
        sint.webhook_secret = "foo"
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          prompt: "",
          prompt_is_secret: false,
          post_to_url: "",
          complete: true,
          output: match("Inbound Messages will be synced as they come in."),
        )
      end
    end

    describe "calculate_backfill_state_machine" do
      it "errors since backfill is not supported" do
        sm = sint.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          complete: true,
          error_code: "postmark_no_inbound_backfill",
          output: match("yet support backfilling"),
        )
      end
    end
  end
end
