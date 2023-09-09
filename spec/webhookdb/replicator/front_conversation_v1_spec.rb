# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::FrontConversationV1, :db do
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }
  let(:root) { fac.create(service_name: "front_marketplace_root_v1", backfill_key: "front_test_auth_token") }
  let(:sint) { fac.depending_on(root).create(service_name: "front_conversation_v1").refresh }
  let(:svc) { sint.replicator }

  it_behaves_like "a replicator", "front_conversation_v1" do
    let(:body) do
      JSON.parse(<<~J)
        {
          "authorization": {
            "id": "cmp_4thp0"
          },
          "type": "conversation_archived",
          "payload": {
            "_links": {
              "self": "https://webhookdb.api.frontapp.com/events/evt_3s3u172s"
            },
            "id": "evt_3s3u172s",
            "type": "archive",
            "emitted_at": 1693940000.063,
            "conversation": {
              "_links": {
                "self": "https://webhookdb.api.frontapp.com/conversations/cnv_1033w6l0",
                "related": {
                  "events": "https://webhookdb.api.frontapp.com/conversations/cnv_1033w6l0/events",
                  "followers": "https://webhookdb.api.frontapp.com/conversations/cnv_1033w6l0/followers",
                  "messages": "https://webhookdb.api.frontapp.com/conversations/cnv_1033w6l0/messages",
                  "comments": "https://webhookdb.api.frontapp.com/conversations/cnv_1033w6l0/comments",
                  "inboxes": "https://webhookdb.api.frontapp.com/conversations/cnv_1033w6l0/inboxes",
                  "last_message": "https://webhookdb.api.frontapp.com/messages/msg_1s8q62z8?referer=conversation"
                }
              },
              "id": "cnv_1033w6l0",
              "subject": "Package update?",
              "status": "archived",
              "assignee": {
                "_links": {
                  "self": "https://webhookdb.api.frontapp.com/teammates/tea_a0lec",
                  "related": {
                    "inboxes": "https://webhookdb.api.frontapp.com/teammates/tea_a0lec/inboxes",
                    "conversations": "https://webhookdb.api.frontapp.com/teammates/tea_a0lec/conversations"
                  }
                },
                "id": "tea_a0lec",
                "email": "natalie@lithic.tech",
                "username": "natalie",
                "first_name": "Natalie",
                "last_name": "Edson",
                "is_admin": true,
                "is_available": true,
                "is_blocked": false,
                "custom_fields": {}
              },
              "recipient": {
                "_links": {
                  "related": {
                    "contact": "https://webhookdb.api.frontapp.com/contacts/crd_3h53wd0"
                  }
                },
                "name": "Sabrina Calhoun",
                "handle": "sabrina@fictionalcustomer.com",
                "role": "to"
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
                },
                {
                  "_links": {
                    "self": "https://webhookdb.api.frontapp.com/tags/tag_3u1a1g",
                    "related": {
                      "conversations": "https://webhookdb.api.frontapp.com/tags/tag_3u1a1g/conversations",
                      "owner": "https://webhookdb.api.frontapp.com/teammates/tea_a0lec",
                      "parent_tag": null,
                      "children": null
                    }
                  },
                  "id": "tag_3u1a1g",
                  "name": "Inbox",
                  "highlight": null,
                  "is_private": true,
                  "is_visible_in_conversation_lists": false,
                  "updated_at": 1692808371.386,
                  "created_at": 1692808371.386
                }
              ],
              "links": [],
              "custom_fields": {},
              "last_message": {
                "_links": {
                  "self": "https://webhookdb.api.frontapp.com/messages/msg_1s8q62z8",
                  "related": {
                    "conversation": "https://webhookdb.api.frontapp.com/conversations/cnv_1033w6l0",
                    "message_seen": "https://webhookdb.api.frontapp.com/messages/msg_1s8q62z8/seen",
                    "message_replied_to": "https://webhookdb.api.frontapp.com/messages/msg_1s8q62z8/parent"
                  }
                },
                "id": "msg_1s8q62z8",
                "type": "email",
                "is_inbound": false,
                "created_at": 1693940000.313,
                "blurb": "ugvkbhl;l;",
                "body": "\u003cdiv\u003e\u003c/div\u003e",
                "text": "ugvkbhl;l;",
                "error_type": null,
                "version": null,
                "subject": "Re: Package update?",
                "draft_mode": null,
                "metadata": {},
                "author": {
                  "_links": {
                    "self": "https://webhookdb.api.frontapp.com/teammates/tea_a0lec",
                    "related": {
                      "inboxes": "https://webhookdb.api.frontapp.com/teammates/tea_a0lec/inboxes",
                      "conversations": "https://webhookdb.api.frontapp.com/teammates/tea_a0lec/conversations"
                    }
                  },
                  "id": "tea_a0lec",
                  "email": "natalie@lithic.tech",
                  "username": "natalie",
                  "first_name": "Natalie",
                  "last_name": "Edson",
                  "is_admin": true,
                  "is_available": true,
                  "is_blocked": false,
                  "custom_fields": {}
                },
                "recipients": [
                  {
                    "_links": {
                      "related": {
                        "contact": null
                      }
                    },
                    "name": null,
                    "handle": "mylittleshop@yourfictionalcompany.com",
                    "role": "from"
                  },
                  {
                    "_links": {
                      "related": {
                        "contact": "https://webhookdb.api.frontapp.com/contacts/crd_3h53wd0"
                      }
                    },
                    "name": "Sabrina Calhoun",
                    "handle": "sabrina@fictionalcustomer.com",
                    "role": "to"
                  }
                ],
                "attachments": [],
                "signature": null,
                "is_draft": false
              },
              "created_at": 1693939978.258,
              "is_private": false,
              "scheduled_reminders": [],
              "metadata": {}
            },
            "source": {
              "_meta": {
                "type": "teammate"
              },
              "data": {
                "_links": {
                  "self": "https://webhookdb.api.frontapp.com/teammates/tea_a0lec",
                  "related": {
                    "inboxes": "https://webhookdb.api.frontapp.com/teammates/tea_a0lec/inboxes",
                    "conversations": "https://webhookdb.api.frontapp.com/teammates/tea_a0lec/conversations"
                  }
                },
                "id": "tea_a0lec",
                "email": "natalie@lithic.tech",
                "username": "natalie",
                "first_name": "Natalie",
                "last_name": "Edson",
                "is_admin": true,
                "is_available": true,
                "is_blocked": false,
                "custom_fields": {}
              }
            }
          }
        }
      J
    end

    let(:expected_data) { body.dig("payload", "conversation") }
  end

  it_behaves_like "a replicator dependent on another", "front_conversation_v1", "front_marketplace_root_v1" do
    let(:no_dependencies_message) { "This integration requires Front Auth to sync" }
  end

  describe "state machine calculation" do
    describe "calculate_webhook_state_machine" do
      it "prompts for dependencies" do
        sint.update(depends_on: nil)
        root.destroy
        sm = sint.replicator.calculate_webhook_state_machine
        expect(sm).to have_attributes(
          output: match("This integration requires Front Auth"),
        )
      end

      it "succeeds and prints a success response if the dependency is set" do
        sm = sint.replicator.calculate_webhook_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          complete: true,
          output: match("now listening for Front Conversation"),
        )
      end
    end
  end
end
