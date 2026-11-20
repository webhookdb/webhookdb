# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::FrontMessageV1, :db do
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }
  let(:root) { fac.create(service_name: "front_marketplace_root_v1", backfill_key: "front_test_auth_token") }
  let(:sint) { fac.depending_on(root).create(service_name: "front_message_v1").refresh }
  let(:svc) { sint.replicator }

  it_behaves_like "a replicator" do
    let(:body) do
      JSON.parse(<<~J)
        {
          "authorization": {
            "id": "cmp_4thp0"
          },
          "type": "inbound_received",
          "payload": {
            "_links": {
              "self": "https://webhookdb.api.frontapp.com/events/evt_3s78kxhw"
            },
            "id": "evt_3s78kxhw",
            "type": "inbound",
            "emitted_at": 1694046470.93,
            "conversation": {
              "_links": {
                "self": "https://webhookdb.api.frontapp.com/conversations/cnv_1042nr10",
                "related": {
                  "events": "https://webhookdb.api.frontapp.com/conversations/cnv_1042nr10/events",
                  "followers": "https://webhookdb.api.frontapp.com/conversations/cnv_1042nr10/followers",
                  "messages": "https://webhookdb.api.frontapp.com/conversations/cnv_1042nr10/messages",
                  "comments": "https://webhookdb.api.frontapp.com/conversations/cnv_1042nr10/comments",
                  "inboxes": "https://webhookdb.api.frontapp.com/conversations/cnv_1042nr10/inboxes",
                  "last_message": "https://webhookdb.api.frontapp.com/messages/msg_1sagx9sk?referer=conversation"
                }
              },
              "id": "cnv_1042nr10",
              "subject": "Package update?",
              "status": "unassigned",
              "assignee": null,
              "recipient": {
                "_links": {
                  "related": {
                    "contact": "https://webhookdb.api.frontapp.com/contacts/crd_3h53wd0"
                  }
                },
                "name": "Sabrina Calhoun",
                "handle": "sabrina@fictionalcustomer.com",
                "role": "from"
              },
              "tags": [
                {
                  "_links": {
                    "self": "https://webhookdb.api.frontapp.com/tags/tag_3u1ahg",
                    "related": {
                      "conversations": "https://webhookdb.api.frontapp.com/tags/tag_3u1ahg/conversations",
                      "owner": "https://webhookdb.api.frontapp.com/teams/tim_4yztg",
                      "parent_tag": null,
                      "children": null
                    }
                  },
                  "id": "tag_3u1ahg",
                  "name": "Front Demo",
                  "highlight": "pink",
                  "is_private": false,
                  "is_visible_in_conversation_lists": false,
                  "updated_at": 1692808372.298,
                  "created_at": 1692808372.298
                },
                {
                  "_links": {
                    "self": "https://webhookdb.api.frontapp.com/tags/tag_3u1ams",
                    "related": {
                      "conversations": "https://webhookdb.api.frontapp.com/tags/tag_3u1ams/conversations",
                      "owner": "https://webhookdb.api.frontapp.com/teammates/tea_a0ljo",
                      "parent_tag": null,
                      "children": null
                    }
                  },
                  "id": "tag_3u1ams",
                  "name": "Inbox",
                  "highlight": null,
                  "is_private": true,
                  "is_visible_in_conversation_lists": false,
                  "updated_at": 1692808372.453,
                  "created_at": 1692808372.453
                },
                {
                  "_links": {
                    "self": "https://webhookdb.api.frontapp.com/tags/tag_3u1aj8",
                    "related": {
                      "conversations": "https://webhookdb.api.frontapp.com/tags/tag_3u1aj8/conversations",
                      "owner": "https://webhookdb.api.frontapp.com/teammates/tea_a0lhw",
                      "parent_tag": null,
                      "children": null
                    }
                  },
                  "id": "tag_3u1aj8",
                  "name": "Inbox",
                  "highlight": null,
                  "is_private": true,
                  "is_visible_in_conversation_lists": false,
                  "updated_at": 1692808372.345,
                  "created_at": 1692808372.345
                }
              ],
              "links": [],
              "custom_fields": {},
              "last_message": {
                "_links": {
                  "self": "https://webhookdb.api.frontapp.com/messages/msg_1sagx9sk",
                  "related": {
                    "conversation": "https://webhookdb.api.frontapp.com/conversations/cnv_1042nr10",
                    "message_seen": "https://webhookdb.api.frontapp.com/messages/msg_1sagx9sk/seen"
                  }
                },
                "id": "msg_1sagx9sk",
                "type": "email",
                "is_inbound": true,
                "created_at": 1694046470.93,
                "blurb": "Hi, I placed an order last week with Brandon. When will it be delivered?",
                "body": "Hi,\n\u003cbr /\u003e\u003cbr /\u003e\nI placed an order last week with Brandon. When will it be delivered?\n",
                "text": "Hi,\n\nI placed an order last week with Brandon. When will it be delivered?",
                "error_type": null,
                "version": null,
                "subject": "Package update?",
                "draft_mode": null,
                "metadata": {},
                "author": null,
                "recipients": [
                  {
                    "_links": {
                      "related": {
                        "contact": "https://webhookdb.api.frontapp.com/contacts/crd_3h53wd0"
                      }
                    },
                    "name": "Sabrina Calhoun",
                    "handle": "sabrina@fictionalcustomer.com",
                    "role": "from"
                  },
                  {
                    "_links": {
                      "related": {
                        "contact": null
                      }
                    },
                    "name": null,
                    "handle": "mylittleshop@yourfictionalcompany.com",
                    "role": "to"
                  }
                ],
                "attachments": [],
                "signature": null,
                "is_draft": false
              },
              "created_at": 1694046470.978,
              "is_private": false,
              "scheduled_reminders": [],
              "metadata": {}
            },
            "source": {
              "_meta": {
                "type": "inboxes"
              },
              "data": [
                {
                  "_links": {
                    "self": "https://webhookdb.api.frontapp.com/inboxes/inb_axnro",
                    "related": {
                      "channels": "https://webhookdb.api.frontapp.com/inboxes/inb_axnro/channels",
                      "conversations": "https://webhookdb.api.frontapp.com/inboxes/inb_axnro/conversations",
                      "teammates": "https://webhookdb.api.frontapp.com/inboxes/inb_axnro/teammates",
                      "owner": "https://webhookdb.api.frontapp.com/teams/tim_4yztg"
                    }
                  },
                  "id": "inb_axnro",
                  "name": "[Sample] Support",
                  "is_private": false,
                  "is_public": true,
                  "address": "dw2z8-dd858e102e6c3e5f39d6@in.frontapp.com",
                  "send_as": "mylittleshop@yourfictionalcompany.com",
                  "type": "smtp",
                  "custom_fields": {}
                }
              ]
            },
            "target": {
              "_meta": {
                "type": "message"
              },
              "data": {
                "_links": {
                  "self": "https://webhookdb.api.frontapp.com/messages/msg_1sagx9sk",
                  "related": {
                    "conversation": "https://webhookdb.api.frontapp.com/conversations/cnv_1042nr10",
                    "message_seen": "https://webhookdb.api.frontapp.com/messages/msg_1sagx9sk/seen"
                  }
                },
                "id": "msg_1sagx9sk",
                "type": "email",
                "is_inbound": true,
                "created_at": 1694046470.93,
                "blurb": "Hi, I placed an order last week with Brandon. When will it be delivered?",
                "body": "Hi,\n\u003cbr /\u003e\u003cbr /\u003e\nI placed an order last week with Brandon. When will it be delivered?\n",
                "text": "Hi,\n\nI placed an order last week with Brandon. When will it be delivered?",
                "error_type": null,
                "version": null,
                "subject": "Package update?",
                "draft_mode": null,
                "metadata": {},
                "author": null,
                "recipients": [
                  {
                    "_links": {
                      "related": {
                        "contact": "https://webhookdb.api.frontapp.com/contacts/crd_3h53wd0"
                      }
                    },
                    "name": "Sabrina Calhoun",
                    "handle": "sabrina@fictionalcustomer.com",
                    "role": "from"
                  },
                  {
                    "_links": {
                      "related": {
                        "contact": null
                      }
                    },
                    "name": null,
                    "handle": "mylittleshop@yourfictionalcompany.com",
                    "role": "to"
                  }
                ],
                "attachments": [],
                "signature": null,
                "is_draft": false
              }
            }
          }
        }
      J
    end

    let(:expected_data) { body.dig("payload", "target", "data") }
  end

  describe "state machine calculation" do
    describe "calculate_webhook_state_machine" do
      it "tells the user to set up the integration through the app store" do
        sm = sint.replicator.calculate_webhook_state_machine
        expect(sm).to have_attributes(
          output: match("Front integrations can only be enabled through the Front App Store"),
        )
      end
    end
  end
end
