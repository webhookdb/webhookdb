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

  describe "unsuaul bodies" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "postmark_inbound_message_v1") }
    let(:svc) { Webhookdb::Replicator.create(sint) }

    before(:each) do
      sint.organization.prepare_database_connections
      svc.create_table
    end

    after(:each) do
      sint.organization.remove_related_database
    end

    it "can handle (UTC) tz" do
      body = JSON.parse(<<~J)
        {
          "FromName": "Lime",
          "MessageStream": "inbound",
          "From": "no-reply@li.me",
          "FromFull": {
            "Email": "no-reply@li.me",
            "Name": "Lime",
            "MailboxHash": ""
          },
          "To": "\\"Lime Rider\\" \u003cu1@in-dev.mysuma.org\u003e",
          "ToFull": [
            {
              "Email": "u1@in-dev.mysuma.org",
              "Name": "Lime Rider",
              "MailboxHash": ""
            }
          ],
          "Cc": "",
          "CcFull": [],
          "Bcc": "",
          "BccFull": [],
          "OriginalRecipient": "u1@in-dev.mysuma.org",
          "Subject": "Lime - Sign In",
          "MessageID": "1cc276c0-fae9-4793-b2c7-71c9cd45e023",
          "ReplyTo": "",
          "MailboxHash": "",
          "Date": "Wed, 05 Jul 2023 22:27:31 +0000 (UTC)",
          "TextBody": "Hello Lime Rider!",
          "HtmlBody": "\\u003c!DOCTYPE html PUBLIC \\"",
          "StrippedTextReply": "",
          "Tag": "",
          "Headers": [
            {
              "Name": "X-Entity-ID",
              "Value": "L3Sx1tGADZEBfpfajFv1Pw=="
            }
          ],
          "Attachments": []
        }
      J
      svc.upsert_webhook_body(body)
      svc.readonly_dataset do |ds|
        expect(ds.first).to include(timestamp: match_time("2023-07-05T22:27:31Z"))
      end
    end
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

    describe "calculate_webhook_state_machine" do
      it "prompts with instructions" do
        sm = sint.replicator.calculate_webhook_state_machine
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
        sm = sint.replicator.calculate_webhook_state_machine
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
  end
end
