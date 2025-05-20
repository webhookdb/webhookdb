# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::FrontSignalwireMessageChannelAppV1, :db do
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }
  let(:signalwire_sint) { fac.create(service_name: "signalwire_message_v1") }
  let(:sint) { fac.depending_on(signalwire_sint).create(service_name: "front_signalwire_message_channel_app_v1") }
  let(:svc) { sint.replicator }
  let(:now) { Time.now }

  def signalwire_message(sid, at:, from:, to:, status:, **more)
    return {
      account_sid: "AC123",
      api_version: "2010-04-01",
      body: "body",
      date_created: at.iso8601,
      date_sent: at.iso8601,
      date_updated: at.iso8601,
      direction: "outbound-api",
      error_code: nil,
      error_message: nil,
      from:,
      messaging_service_sid: nil,
      num_media: 0,
      num_segments: 1,
      price: -0.00750,
      price_unit: "USD",
      sid:,
      status:,
      subresource_uris: {
        media: "/api/laml/2010-04-01/Accounts/AC123/Messages/#{sid}/Media.json",
      },
      to:,
      uri: "/api/laml/2010-04-01/Accounts/AC123/Messages/#{sid}.json",
    }.merge(more).as_json
  end

  def signalwire_message_simple(sid, **more)
    kw = {
      at: now,
      from: "+15559235161",
      status: "sent",
      to: "+15552008801",
    }
    kw.merge!(**more)
    return signalwire_message(sid, **kw)
  end

  it_behaves_like "a replicator", supports_row_diff: false do
    let(:sint) { super().update(api_url: "2223334444") }
    let(:body) do
      {
        "type" => "message_autoreply",
        "payload" => {
          "_links" => {
            "related" => {
              "conversation" => "https://api2.frontapp.com/conversations/cnv_55c8c149",
              "message_replied_to" => "https://api2.frontapp.com/messages/msg_1ab23cd4",
            },
          },
          "type" => "auto_reply",
          "is_inbound" => false,
          "created_at" => 1_453_770_984.123,
          "body" => "I'll get back to you as soon as possible.",
          "text" => "I'll get back to you as soon as possible.",
          "recipients" => [{"_links" => {"related" => {"contact" => "https://api2.frontapp.com/contacts/crd_55c8c149"}},
                            "handle" => "9998887777", "role" => "to",}],
          "attachments" => [],
        },
        "front_message_id" => "msg_1ab23cd4_autoreply",
        "external_id" => "msg_1ab23cd4_autoreply",
        "direction" => "outbound",
        "body" => "I'll get back to you as soon as possible.",
        "sender" => "https://fake-url.com",
        "recipient" => "9998887777",
        "external_conversation_id" => "9998887777",
      }
    end
    let(:expected_row) do
      include(
        sender: "+12223334444",
        recipient: "+19998887777",
        body: "I'll get back to you as soon as possible.",
        direction: "outbound",
        external_conversation_id: "+19998887777",
        external_id: "msg_1ab23cd4_autoreply-+19998887777",
        front_message_id: "msg_1ab23cd4_autoreply",
      )
    end
  end

  it_behaves_like "a replicator dependent on another", "signalwire_message_v1" do
    let(:no_dependencies_message) { "This integration requires SignalWire Messages to sync" }
  end

  describe "upsert_webhook" do
    before(:each) do
      sint.update(api_url: "+2223334444")
      sint.organization.prepare_database_connections
      svc.create_table
    end

    after(:each) do
      sint.organization.remove_related_database
    end

    it "does not overwrite if signalwire and front ids are set" do
      body = {
        "external_id" => "some_id",
        "signalwire_sid" => "sw_id",
        "direction" => "inbound",
        "body" => "initial insert",
        "sender" => "+2223334444",
        "recipient" => "+5556667777",
        "external_conversation_id" => "convo",
      }

      # Initial upsert adds the row
      svc.upsert_webhook_body(body)
      expect(svc.admin_dataset(&:all)).to contain_exactly(
        include(
          signalwire_sid: "sw_id",
          front_message_id: nil,
          body: "initial insert",
        ),
      )

      # Update can modify the row
      body["body"] = "secondinsert"
      expect(svc.admin_dataset(&:all)).to contain_exactly(
        include(
          signalwire_sid: "sw_id",
          front_message_id: nil,
          body: "initial insert",
        ),
      )

      # Replacing the ID should work (though we'd never do this in reality)
      body.delete("signalwire_sid")
      body["front_message_id"] = "frontid"
      body["body"] = "front msg"
      svc.upsert_webhook_body(body)
      expect(svc.admin_dataset(&:all)).to contain_exactly(
        include(
          signalwire_sid: nil,
          front_message_id: "frontid",
          body: "front msg",
        ),
      )

      # Setting both IDs works
      body["signalwire_sid"] = "sw_id"
      body["front_message_id"] = "front_id"
      body["body"] = "combined"
      svc.upsert_webhook_body(body)
      expect(svc.admin_dataset(&:all)).to contain_exactly(
        include(
          signalwire_sid: "sw_id",
          front_message_id: "front_id",
          body: "combined",
        ),
      )

      # Once both IDs are set, we cannot modify the row
      body["body"] = "updated body"
      svc.upsert_webhook_body(body)
      expect(svc.admin_dataset(&:all)).to contain_exactly(
        include(
          signalwire_sid: "sw_id",
          front_message_id: "front_id",
          body: "combined",
        ),
      )
    end

    it "enques a backfill when any rows change" do
      body = {
        "external_id" => "some_id",
        # Needs both ids, so the second upsert does not change.
        "front_message_id" => "front_id",
        "signalwire_sid" => "sw_id",
        "direction" => "inbound",
        "body" => "initial insert",
        "sender" => "+2223334444",
        "recipient" => "+5556667777",
        "external_conversation_id" => "convo",
      }
      svc.upsert_webhook_body(body)
      expect(Webhookdb::BackfillJob.all).to have_length(1)
      svc.upsert_webhook_body(body)
      expect(Webhookdb::BackfillJob.all).to have_length(1)
    end

    it "upserts a front message" do
      payload = {
        _links: {
          self: "https://api2.frontapp.com/messages/msg_55c8c149",
          related: {
            conversation: "https://api2.frontapp.com/conversations/cnv_55c8c149",
            message_replied_to: "https://api2.frontapp.com/messages/msg_1ab23cd4",
          },
        },
        id: "msg_55c8c149",
        type: "email",
        is_inbound: true,
        draft_mode: nil,
        created_at: 1_453_770_984.123,
        blurb: "Anything less than immortality is a...",
        author: {},
        recipients: [
          {
            _links: {
              related: {
                contact: "https://api2.frontapp.com/contacts/crd_55c8c149",
              },
            },
            handle: "9998887777",
            role: "to",
          },
        ],
        body: "Anything less than immortality is a complete waste of time.",
        text: "Anything less than immortality is a complete waste of time.",
        attachments: [],
        metadata: {},
      }
      svc.upsert_webhook_body({type: "message", payload:}.as_json)
      expect(svc.admin_dataset(&:all)).to contain_exactly(
        include(
          external_id: "msg_55c8c149-+19998887777",
          signalwire_sid: nil,
          front_message_id: "msg_55c8c149",
          external_conversation_id: "+19998887777",
          direction: "outbound",
          body: "Anything less than immortality is a complete waste of time.",
          sender: "+12223334444",
          recipient: "+19998887777",
        ),
      )
    end

    it "upserts a front autoreply" do
      payload = {
        _links: {
          related: {
            conversation: "https://api2.frontapp.com/conversations/cnv_55c8c149",
            message_replied_to: "https://api2.frontapp.com/messages/msg_1ab23cd4",
          },
        },
        type: "auto_reply",
        is_inbound: false,
        created_at: 1_453_770_984.123,
        body: "I'll get back to you as soon as possible.",
        text: "I'll get back to you as soon as possible.",
        recipients: [
          {
            _links: {
              related: {
                contact: "https://api2.frontapp.com/contacts/crd_55c8c149",
              },
            },
            handle: "9998887777",
            role: "to",
          },
        ],
        attachments: [],
      }
      svc.upsert_webhook_body({type: "message_autoreply", payload:}.as_json)
      expect(svc.admin_dataset(&:all)).to contain_exactly(
        include(
          external_id: "msg_1ab23cd4_autoreply-+19998887777",
          signalwire_sid: nil,
          front_message_id: "msg_1ab23cd4_autoreply",
          external_conversation_id: "+19998887777",
          direction: "outbound",
          body: "I'll get back to you as soon as possible.",
          sender: "+12223334444",
          recipient: "+19998887777",
        ),
      )
    end
  end

  describe "synchronous_processing_response_body" do
    def doit(body, upserted=[])
      return svc.synchronous_processing_response_body(
        upserted:,
        request: Webhookdb::Replicator::WebhookRequest.new(body: body.as_json),
      )
    end

    it "stores the channel_id on authorization" do
      got = doit({type: "authorization", payload: {channel_id: "ch_abc"}})
      expect(sint.refresh).to have_attributes(backfill_key: "ch_abc")
      expect(got).to eq('{"type":"success","webhook_url":"http://localhost:18001/v1/install/front_signalwire/channel"}')
    end

    it "destroys the service integration and related table on delete" do
      org.prepare_database_connections
      sint.replicator.create_table
      got = doit({type: "delete", payload: {channel_id: "ch_abc"}})
      expect(got).to eq("{}")
      expect(sint).to be_destroyed
      expect do
        org.admin_connection do |db|
          db[sint.table_name.to_sym].all
        end
      end.to raise_error(Sequel::DatabaseError, /PG::UndefinedTable/)
    ensure
      org.remove_related_database
    end

    it "errors for other types" do
      got = doit({type: "something else"})
      expect(got).to eq("{}")
    end

    it "returns the external and convo ids for message and autoreply types" do
      got = doit({type: "message"}, [{external_id: "eid", external_conversation_id: "convoid"}])
      expect(got).to eq('{"type":"success","external_id":"eid","external_conversation_id":"convoid"}')
    end

    it "handles multiple upserted convos" do
      got = doit(
        {type: "message"},
        [
          {external_id: "e1", external_conversation_id: "ec1"},
          {external_id: "e2", external_conversation_id: "ec2"},
        ],
      )
      expect(got).to eq('{"type":"success","external_id":"e1,e2","external_conversation_id":"ec1,ec2"}')
    end
  end

  describe "on_dependency_webhook_upsert" do
    let(:customer_phone) { data.fetch("from") }
    let(:support_phone) { data.fetch("to") }
    let(:data) { JSON.parse(<<~JSON) }
      {
        "account_sid": "AC123",
        "api_version": "2010-04-01",
        "body": "body",
        "date_created": "Thu, 30 Jul 2015 20:12:31 +0000",
        "date_sent": "Thu, 30 Jul 2015 20:12:33 +0000",
        "date_updated": "Thu, 30 Jul 2015 20:12:33 +0000",
        "direction": "inbound",
        "error_code": null,
        "error_message": null,
        "from": "+15017122661",
        "messaging_service_sid": "MGXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
        "num_media": 0,
        "num_segments": "1",
        "price": null,
        "price_unit": null,
        "sid": "SMXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
        "status": "sent",
        "subresource_uris": {
          "media": "/2010-04-01/Accounts/AC123/Messages/SMXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/Media.json"
        },
        "to": "+15558675310",
        "uri": "/2010-04-01/Accounts/AC123/Messages/SMXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX.json"
      }
    JSON
    let(:row) { signalwire_sint.replicator.upsert_webhook_body(data, upsert: false) }

    before(:each) do
      sint.update(api_url: support_phone)
    end

    it "noops if the signalwire row has not changed" do
      expect do
        svc.on_dependency_webhook_upsert(signalwire_sint.replicator, row, changed: false)
      end.to_not raise_error
    end

    it "noops for outbound messages" do
      row[:direction] = "outbound-api"
      expect do
        svc.on_dependency_webhook_upsert(signalwire_sint.replicator, row, changed: true)
      end.to_not raise_error
    end

    it "upserts a row for inbound messages, and enqueues a backfill" do
      sint.organization.prepare_database_connections
      svc.create_table
      svc.on_dependency_webhook_upsert(signalwire_sint.replicator, row, changed: true)
      expect(svc.admin_dataset(&:all)).to contain_exactly(
        include(
          external_id: "SMXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
          signalwire_sid: "SMXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
          front_message_id: nil,
          external_conversation_id: "+15017122661",
          direction: "inbound",
          body: "body",
          sender: customer_phone,
          recipient: support_phone,
        ),
      )
    ensure
      sint.organization.remove_related_database
    end

    it "noops inbound messages from an unconfigured number" do
      row[:to] = "+15552223333"
      expect do
        svc.on_dependency_webhook_upsert(signalwire_sint.replicator, row, changed: true)
      end.to_not raise_error
    end

    describe "when the message status is failed/undelivered", truncate: Webhookdb::Idempotency do
      before(:each) do
        sint.organization.prepare_database_connections
        signalwire_sint.replicator.create_table
        sint.update(backfill_key: "chanid1")
        svc.create_table
      end

      after(:each) do
        sint.organization.remove_related_database
      end

      it "imports a message about the failed signalwire send into Front" do
        Timecop.freeze(now) do
          failrow_req = stub_request(:post, "https://api2.frontapp.com/channels/chanid1/inbound_messages").
            with(
              body: {
                sender: {handle: "+15017122661"},
                body: "SMS failed to send. Error (30008): Unknown error\nbody",
                delivered_at: now.to_i,
                metadata: {
                  external_id: "failedrow",
                  external_conversation_id: "+15017122661",
                },
              }.to_json,
            ).to_return(status: 200, body: "", headers: {})
          failed_row = signalwire_sint.replicator.upsert_webhook_body(
            signalwire_message(
              "failedrow",
              at: now,
              from: support_phone,
              to: customer_phone,
              status: "failed",
              error_code: "30008",
              error_message: "Unknown error",
            ),
          )
          undelrow_req = stub_request(:post, "https://api2.frontapp.com/channels/chanid1/inbound_messages").
            with(
              body: {
                sender: {handle: "+15559998881"},
                body: "SMS failed to send. Error (-): -\naaaaaaaaaaaaaaaaaaaaaaaaaa",
                delivered_at: now.to_i,
                metadata: {
                  external_id: "undeliveredrow",
                  external_conversation_id: "+15559998881",
                },
              }.to_json,
            ).to_return(status: 200, body: "", headers: {})
          undel_row = signalwire_sint.replicator.upsert_webhook_body(
            signalwire_message(
              "undeliveredrow",
              at: now,
              from: support_phone,
              to: "+15559998881",
              status: "undelivered",
              body: "a" * 250,
            ),
          )
          # These rows do not trigger imports into Front.
          # Row is already delivered, so it's not a failure.
          del_row = signalwire_sint.replicator.upsert_webhook_body(
            signalwire_message("delivrow", at: now, from: support_phone, to: customer_phone, status: "delivered"),
          )
          # Row is too old to notify about.
          old_row = signalwire_sint.replicator.upsert_webhook_body(
            signalwire_message("oldrow", at: 20.days.ago, from: support_phone, to: customer_phone, status: "failed"),
          )
          # Row is not from the configured support number.
          alt_num_row = signalwire_sint.replicator.upsert_webhook_body(
            signalwire_message("othernum", at: now, from: "19992223333", to: customer_phone, status: "failed"),
          )
          expect(failrow_req).to have_been_made
          expect(undelrow_req).to have_been_made
        end
      end
    end
  end

  describe "state machine calculation" do
    describe "calculate_webhook_state_machine" do
      it "requires for the signalwire dependency" do
        sint.update(depends_on: nil)
        signalwire_sint.destroy
        sm = sint.replicator.calculate_webhook_state_machine
        expect(sm).to have_attributes(
          output: include("This integration requires SignalWire Messages to sync"),
          complete: true,
        )
      end

      it "prompts for the signalwire phone number" do
        sint.update(api_url: "")
        sm = sint.replicator.calculate_webhook_state_machine
        expect(sm).to have_attributes(
          output: include("This Front Channel will be linked to a specific number in SignalWire"), needs_input: true,
          prompt: be_present,
          prompt_is_secret: false,
          post_to_url: end_with("/transition/api_url"),
          complete: false,
        )
      end

      it "succeeds and prints a success response if fields are set" do
        sint.update(api_url: "2223334444")
        sm = sint.replicator.calculate_webhook_state_machine
        expect(sm).to have_attributes(
          output: include("Almost there! You can now finish installing the"),
          needs_input: false,
          complete: true,
        )
        expect(sint.refresh).to have_attributes(webhookdb_api_key: start_with("sk/svi_"))
      end
    end

    describe "calculate_backfill_state_machine" do
      it "is the same as the webhook state machine" do
        sm = sint.replicator.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          output: include("You can now finish installing the SignalWire Channel in Front"),
        )
      end
    end
  end

  describe "clear_webhook_information" do
    it "clears backfill info too" do
      sint.api_url = "hi"
      svc.clear_webhook_information
      expect(sint).to have_attributes(api_url: "")
    end
  end

  describe "backfill", reset_configuration: Webhookdb::Signalwire, truncate: Webhookdb::Idempotency do
    support_phone = "2223334444"
    customer_phone = "5556667777"
    before(:each) do
      signalwire_sint.update(backfill_key: "projid", backfill_secret: "apikey", api_url: "whdbtest")
      sint.replicator.front_channel_id = "fchan1"
      sint.update(api_url: support_phone)
      sint.organization.prepare_database_connections
      signalwire_sint.replicator.create_table
      svc.create_table
      Webhookdb::Signalwire.sms_allowlist = ["*"]
    end

    after(:each) do
      sint.organization.remove_related_database
    end

    it "sends a Signalwire SMS for rows without a Signalwire id", :no_transaction_check do
      svc.admin_dataset do |ds|
        ds.insert(
          external_id: "front_id_only",
          front_message_id: "fmid1",
          sender: support_phone,
          recipient: customer_phone,
          body: "hi",
          data: {payload: {created_at: Time.parse("2023-01-10T12:00:00Z").to_i}}.to_json,
        )
        ds.insert(
          external_id: "OLD_front_id_only",
          front_message_id: "OLD_fmid1",
          sender: support_phone,
          recipient: customer_phone,
          body: "hi",
          data: {payload: {created_at: Time.parse("2023-01-05T12:00:00Z").to_i}}.to_json,
        )
        ds.insert(external_id: "both_id", front_message_id: "fmid2", signalwire_sid: "swid", data: "{}")
      end
      req = stub_request(:post, "https://whdbtest.signalwire.com/2010-04-01/Accounts/projid/Messages.json").
        with(
          body: {"Body" => "hi", "From" => "+12223334444", "To" => "+15556667777"},
          headers: {
            "Accept" => "application/json",
            "Authorization" => "Basic cHJvamlkOmFwaWtleQ==",
            "Content-Type" => "application/x-www-form-urlencoded",
          },
        ).to_return(json_response({sid: "SWID123"}))
      # Freeze time for age
      Timecop.freeze("2023-01-10T12:00:00Z") do
        backfill(sint)
      end
      expect(req).to have_been_made
      expect(svc.admin_dataset(&:all)).to contain_exactly(
        include(external_id: "front_id_only", front_message_id: "fmid1", signalwire_sid: "SWID123"),
        include(external_id: "both_id", front_message_id: "fmid2", signalwire_sid: "swid"),
        include(external_id: "OLD_front_id_only", front_message_id: "OLD_fmid1", signalwire_sid: "skipped_due_to_age"),
      )
    end

    it "dispatches an alert if the Signalwire SMS send fails", :no_transaction_check do
      Webhookdb::Fixtures.organization_membership.org(org).verified.admin.create
      svc.admin_dataset do |ds|
        ds.insert(
          external_id: "front_id_only",
          front_message_id: "fmid1",
          sender: support_phone,
          recipient: customer_phone,
          body: "hi",
          data: {payload: {created_at: Time.now.to_i}}.to_json,
        )
      end
      req = stub_request(:post, "https://whdbtest.signalwire.com/2010-04-01/Accounts/projid/Messages.json").
        with(
          body: {"Body" => "hi", "From" => "+12223334444", "To" => "+15556667777"},
        ).to_return(json_response(load_fixture_data("signalwire/error_inactive_campaign"), status: 422))
      backfill(sint)
      expect(req).to have_been_made
      expect(svc.admin_dataset(&:all)).to contain_exactly(
        include(external_id: "front_id_only", front_message_id: "fmid1", signalwire_sid: nil),
      )
      expect(Webhookdb::Message::Delivery.all).to contain_exactly(
        have_attributes(template: "errors/signalwire_send_sms"),
      )
    end

    it "raises for unhandled sms send errors", :no_transaction_check do
      svc.admin_dataset do |ds|
        ds.insert(
          external_id: "front_id_only",
          front_message_id: "fmid1",
          sender: support_phone,
          recipient: customer_phone,
          body: "hi",
          data: {payload: {created_at: Time.now.to_i}}.to_json,
        )
      end
      req = stub_request(:post, "https://whdbtest.signalwire.com/2010-04-01/Accounts/projid/Messages.json").
        with(
          body: {"Body" => "hi", "From" => "+12223334444", "To" => "+15556667777"},
        ).to_return(json_response({message: "uh oh"}, status: 422))
      expect { backfill(sint) }.to raise_error(Webhookdb::Http::Error)
      expect(req).to have_been_made
    end

    it "raises for non-json sms errors", :no_transaction_check do
      svc.admin_dataset do |ds|
        ds.insert(
          external_id: "front_id_only",
          front_message_id: "fmid1",
          sender: support_phone,
          recipient: customer_phone,
          body: "hi",
          data: {payload: {created_at: Time.now.to_i}}.to_json,
        )
      end
      req = stub_request(:post, "https://whdbtest.signalwire.com/2010-04-01/Accounts/projid/Messages.json").
        with(
          body: {"Body" => "hi", "From" => "+12223334444", "To" => "+15556667777"},
        ).to_return(status: 500, body: "uh oh")
      expect { backfill(sint) }.to raise_error(Webhookdb::Http::Error)
      expect(req).to have_been_made
    end

    it "syncs a Front message for rows without a Front id", :no_transaction_check do
      svc.admin_dataset do |ds|
        ds.insert(external_id: "both_id", front_message_id: "fmid", signalwire_sid: "swid1", data: "{}")
        ds.insert(
          external_id: "sw_id_only",
          signalwire_sid: "swid2",
          external_conversation_id: "convoid",
          sender: "12223334444",
          recipient: "4445556666",
          body: "hi WHDB",
          data: {date_created: Time.parse("2023-01-10T11:00:00Z").rfc2822}.to_json,
        )
        ds.insert(
          external_id: "OLD_sw_id_only",
          signalwire_sid: "OLD_swid2",
          external_conversation_id: "convoid",
          sender: "12223334444",
          recipient: "4445556666",
          body: "hi WHDB",
          data: {date_created: Time.parse("2023-01-05T11:00:00Z").rfc2822}.to_json,
        )
      end
      signalwire_sint.replicator.upsert_webhook_body(signalwire_message_simple("swid2"))
      expect(Webhookdb::Front).to receive(:channel_jwt_jti).and_return("abcd")
      # rubocop:disable Layout/LineLength
      req = stub_request(:post, "https://api2.frontapp.com/channels/fchan1/inbound_messages").
        with(
          body: {
            sender: {handle: "+12223334444"},
            body: "hi WHDB",
            delivered_at: 1_673_348_400,
            metadata: {external_id: "sw_id_only", external_conversation_id: "convoid"},
          }.as_json,
          headers: {
            "Authorization" => "Bearer eyJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJmcm9udF9zd2NoYW5fYXBwX2lkIiwianRpIjoiYWJjZCIsInN1YiI6ImZjaGFuMSIsImV4cCI6MTY3MzM1MjAzMH0.zPfFtC15CUEJeLpjcP2xU9Wdorzn2JcLLziA6th5TBc",
            "Content-Type" => "application/json",
          },
        ).
        to_return(json_response({message_uid: "FMID2"}, status: 202))
      # rubocop:enable Layout/LineLength

      # Freeze time for Front JWT expiry and age
      Timecop.freeze("2023-01-10T12:00:00Z") do
        backfill(sint)
      end
      expect(req).to have_been_made
      expect(svc.admin_dataset(&:all)).to contain_exactly(
        include(
          external_id: "both_id",
          signalwire_sid: "swid1",
          front_message_id: "fmid",
          data: be_empty,
        ),
        # Use not_includde to verify the data/row splat workaround works.
        include(
          external_id: "sw_id_only",
          signalwire_sid: "swid2",
          front_message_id: "FMID2",
          data: not_include("pk"),
        ),
        include(
          external_id: "OLD_sw_id_only",
          signalwire_sid: "OLD_swid2",
          front_message_id: "skipped_due_to_age",
          data: not_include("pk"),
        ),
      )
    end

    it "syncs a Front message using a default body if the signalwire body is null" do
      t = Time.now
      svc.admin_dataset do |ds|
        ds.insert(
          external_id: "sw_id_only",
          signalwire_sid: "swid2",
          external_conversation_id: "convoid",
          sender: "12223334444",
          recipient: "4445556666",
          body: nil,
          data: {date_created: t.rfc2822}.to_json,
        )
      end
      signalwire_sint.replicator.upsert_webhook_body(signalwire_message_simple("swid2"))
      req = stub_request(:post, "https://api2.frontapp.com/channels/fchan1/inbound_messages").
        with(
          body: {
            sender: {handle: "+12223334444"},
            body: "<no body>",
            delivered_at: t.to_i,
            metadata: {external_id: "sw_id_only", external_conversation_id: "convoid"},
          }.as_json,
        ).
        to_return(json_response({message_uid: "FMID2"}, status: 202))

      backfill(sint)
      expect(req).to have_been_made
      expect(svc.admin_dataset(&:all)).to contain_exactly(
        include(external_id: "sw_id_only", signalwire_sid: "swid2", front_message_id: "FMID2"),
      )
    end

    describe "when the Signalwire message contains media" do
      it "fetches and includes plain/text media as the body and image media as attachments" do
        svc.admin_dataset do |ds|
          ds.insert(
            external_id: "sw_id_only",
            signalwire_sid: "swid2",
            external_conversation_id: "convoid",
            sender: "12223334444",
            recipient: "4445556666",
            body: nil,
            data: signalwire_message_simple("swid2").to_json,
          )
        end
        signalwire_sint.replicator.upsert_webhook_body(signalwire_message_simple("swid2", num_media: 4))

        media_list_req = stub_request(:get, "https://whdbtest.signalwire.com/api/laml/2010-04-01/Accounts/AC123/Messages/swid2/Media.json").
          to_return(json_response(
                      {
                        media_list: [
                          {
                            sid: "media1",
                            content_type: "text/plain",
                            uri: "/api/laml/2010-04-01/Accounts/AC123/Messages/SMabcxyz/Media/media1.json",
                          },
                          {
                            sid: "media2",
                            content_type: "image/jpeg",
                            uri: "/api/laml/2010-04-01/Accounts/AC123/Messages/SMabcxyz/Media/media2.json",
                          },
                          {
                            sid: "media3",
                            content_type: "text/html",
                            uri: "/api/laml/2010-04-01/Accounts/AC123/Messages/SMabcxyz/Media/media3.json",
                          },
                          {
                            sid: "media4",
                            # Unrecognized content type should have .unrek extension but octet-stream mimetype
                            content_type: "image/unrek",
                            uri: "/api/laml/2010-04-01/Accounts/AC123/Messages/SMabcxyz/Media/media4.json",
                          },
                        ],
                      },
                    ))
        media1_req = stub_request(:get, "https://whdbtest.signalwire.com/api/laml/2010-04-01/Accounts/AC123/Messages/SMabcxyz/Media/media1").
          to_return(status: 200, body: "media1 body", headers: {"Content-Type" => "text/plain"})
        media2_req = stub_request(:get, "https://whdbtest.signalwire.com/api/laml/2010-04-01/Accounts/AC123/Messages/SMabcxyz/Media/media2").
          to_return(status: 200, body: "media2 body", headers: {"Content-Type" => "image/jpeg"})
        media4_req = stub_request(:get, "https://whdbtest.signalwire.com/api/laml/2010-04-01/Accounts/AC123/Messages/SMabcxyz/Media/media4").
          to_return(status: 200, body: "media4 body", headers: {"Content-Type" => "image/unrek"})

        # rubocop:disable Layout/LineLength
        front_req = stub_request(:post, "https://api2.frontapp.com/channels/fchan1/inbound_messages").
          with do |req|
          expect(req.body).to include("Content-Disposition: form-data; name=\"sender[handle]\"\r\n\r\n+12223334444")
          expect(req.body).to include("Content-Disposition: form-data; name=\"body\"\r\n\r\nmedia1 body")
          ts = now.strftime("%Y%m%d")
          expect(req.body).to include("Content-Disposition: form-data; name=\"attachments[0]\"; filename=\"#{ts}-attachment1.jpeg\"\r\nContent-Type: image/jpeg\r\n\r\nmedia2 body")
          expect(req.body).to include("Content-Disposition: form-data; name=\"attachments[1]\"; filename=\"#{ts}-attachment2.unrek\"\r\nContent-Type: application/octet-stream\r\n\r\nmedia4 body")
        end.to_return(json_response({message_uid: "FMID2"}, status: 202))
        # rubocop:enable Layout/LineLength

        backfill(sint)
        expect(front_req).to have_been_made
        expect(media_list_req).to have_been_made
        expect([media1_req, media2_req, media4_req]).to all(have_been_made)
        expect(svc.admin_dataset(&:all)).to contain_exactly(
          include(external_id: "sw_id_only", signalwire_sid: "swid2", front_message_id: "FMID2"),
        )
      end

      it "includes information about the issue if the row is not in the parent replicator" do
        svc.admin_dataset do |ds|
          ds.insert(
            external_id: "inbound1",
            signalwire_sid: "swid",
            external_conversation_id: "convoid",
            sender: "12223334444",
            recipient: "4445556666",
            body: nil,
            data: signalwire_message_simple("swid", num_media: 1).to_json,
          )
        end
        req = stub_request(:post, "https://api2.frontapp.com/channels/fchan1/inbound_messages").
          with(
            body: hash_including(
              body: "<no body>\nError: No replicated row for SMS swid found in database, attachments not found.",
            ),
          ).
          to_return(json_response({message_uid: "FMID2"}, status: 202))

        backfill(sint)
        expect(req).to have_been_made
        expect(svc.admin_dataset(&:all)).to contain_exactly(
          include(external_id: "inbound1", signalwire_sid: "swid", front_message_id: "FMID2"),
        )
      end
    end

    describe "when the Front message contains attachments", :no_transaction_check do
      it "creates temporary database documents and sends them to Signalwire" do
        svc.admin_dataset do |ds|
          ds.insert(
            external_id: "front_id_only",
            front_message_id: "fmid1",
            sender: support_phone,
            recipient: customer_phone,
            body: "hi",
            data: {
              payload: {
                created_at: now.to_i,
                attachments: [
                  {
                    id: "fil_50jy51ep",
                    url: "https://myclient.api.frontapp.com/messages/msg_2jre19y9/download/fil_50jy51ep",
                    size: 166_482,
                    filename: "SomeFile.png",
                    metadata: {
                      is_inline: false,
                    },
                    content_type: "image/png",
                  },
                ],
              },
            }.to_json,
          )
        end
        attachment_req = stub_request(:get, "https://myclient.api.frontapp.com/messages/msg_2jre19y9/download/fil_50jy51ep").
          to_return(status: 200, body: "myimage", headers: {"Content-Type" => "image/png"})
        sms_req = stub_request(:post, "https://whdbtest.signalwire.com/2010-04-01/Accounts/projid/Messages.json").
          with(
            body: hash_including(
              "Body" => "hi",
              "MediaUrl" => include("admin_api"),
            ),
          ).to_return(json_response({sid: "SWID123"}))
        Timecop.freeze(now) do
          backfill(sint)
        end
        expect(sms_req).to have_been_made
        expect(attachment_req).to have_been_made
        expect(svc.admin_dataset(&:all)).to contain_exactly(
          include(external_id: "front_id_only", front_message_id: "fmid1", signalwire_sid: "SWID123"),
        )
        expect(Webhookdb::DatabaseDocument.all).to contain_exactly(
          have_attributes(
            key: "front_signalwire_message_channel_app_v1/fil_50jy51ep/SomeFile.png",
            content: "myimage",
            content_type: "image/png",
            delete_at: be > (now + 15.minutes),
          ),
        )
      end
    end
  end
end
