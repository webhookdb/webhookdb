# frozen_string_literal: true

require "support/shared_examples_for_replicators"
require "webhookdb/intercom"

RSpec.describe Webhookdb::Replicator::IntercomConversationV1, :db do
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }
  let(:root) { fac.create(service_name: "intercom_marketplace_root_v1", backfill_key: "intercom_auth_token") }
  let(:sint) { fac.depending_on(root).create(service_name: "intercom_conversation_v1").refresh }
  let(:svc) { sint.replicator }

  it_behaves_like "a replicator" do
    let(:body) { JSON.parse(<<~JSON) }
      {
        "type": "conversation",
        "id": "123",
        "created_at": 1539897198,
        "updated_at": 1540393270,
        "source": {
          "attachments": [],
          "author": {
            "id": "5bc8f7421ae2d96695c18a",
            "type": "lead"
          },
          "body": "<p>Hi</p>",
          "delivered_as": "customer_initiated",
          "id": "269650473",
          "subject": "",
          "type": "conversation",
          "url": "https://intercom-survey-app.glitch.me/",
          "redacted": false
        },
        "contacts": [
          {
            "id": "5bc8f7ae2d96695c18a",
            "type": "lead"
          }
        ],
        "teammates": [
          {
            "id": "814860",
            "type": "admin"
          }
        ],
        "title": "Conversation Title",
        "admin_assignee_id": 814860,
        "team_assignee_id": null,
        "custom_attributes": {
          "issue_type": "Billing",
          "priority": "High"
        },
        "topics": {
          "type": "topic.list",
          "topics": [
            {
              "type": "topic",
              "name": "Example Topic 1",
              "id": 839
            }
          ],
          "total_count": 1
        },
        "open": true,
        "state": "open",
        "read": true,
        "waiting_since": 64654125776,
        "snoozed_until": null,
        "tags": {
          "tags": [],
          "type": "tag.list"
        },
        "first_contact_reply": {
          "created_at": 1539897198,
          "type": "conversation",
          "url": "https://intercom-survey-app.glitch.me/"
        },
        "priority": "not_priority",
        "sla_applied": {
          "sla_name": "VIP customer <5m",
          "sla_status": "missed"
        },
        "conversation_rating": {
          "created_at": null,
          "contact": {
            "id": null,
            "type": null
          },
          "rating": null,
          "remark": null,
          "teammate": {
            "id": null,
            "type": null
          }
        },
        "statistics": {
          "time_to_assignment": 2310,
          "time_to_admin_reply": 2408,
          "time_to_first_close": 4915 ,
          "time_to_last_close": 5125,
          "median_time_to_reply": 321,
          "first_contact_reply_at": 1539897200,
          "first_assignment_at": 1539897200,
          "first_admin_reply_at": 1539897200,
          "first_close_at": 1539897200,
          "last_assignment_at": 1539897200,
          "last_assignment_admin_reply_at": 1539897200,
          "last_contact_reply_at": 1539897200,
          "last_admin_reply_at": 1539897200,
          "last_close_at": 1539897200,
          "last_closed_by": {
            "type": "admin",
            "id": "325432652",
            "name": "Tom Smith",
            "email": "tom@example.com"
          },
          "count_reopens": 3,
          "count_assignments": 2,
          "count_conversation_parts": 67
        },
        "conversation_parts": {
          "conversation_parts": [
            {
              "assigned_to": null,
              "attachments": [],
              "author": {
                "id": "815309",
                "type": "bot"
              },
              "body": "<p>Test_App typically replies in a few hours.</p>",
              "created_at": 1539897200,
              "external_id": null,
              "id": "2202737122",
              "notified_at": 1539897200,
              "part_type": "comment",
              "type": "conversation_part",
              "updated_at": 1539897200,
              "redacted": false
            }
          ],
          "total_count": 67,
          "type": "conversation_part.list"
        }
      }
    JSON

    it "can handle string timestamps" do
      svc.create_table
      body["created_at"] = "2024-03-16T20:16:07.820+00:00"
      body["updated_at"] = "2024-03-17T20:55:59.208+00:00"
      upsert_webhook(svc, body:)
      svc.readonly_dataset do |ds|
        expect(ds.first).to include(
          created_at: Time.parse("2024-03-16T20:16:07.820+00:00"),
          updated_at: Time.parse("2024-03-17T20:55:59.208+00:00"),
        )
      end
    end
  end

  it_behaves_like "a replicator that deals with resources and wrapped events" do
    let(:resource_json) { resource_in_envelope_json.dig("data", "item") }
    let(:resource_in_envelope_json) { JSON.parse(<<~JSON) }
      {
        "type": "notification_event",
        "app_id": "vne310wv",
        "data": {
          "type": "notification_event_data",
          "item": {
            "type": "conversation",
            "id": "123",
            "created_at": 1539897198,
            "updated_at": 1540393270,
            "source": {
              "attachments": [],
              "author": {
                "id": "5bc8f7421ae2d96695c18a",
                "type": "lead"
              },
              "body": "<p>Hi</p>",
              "delivered_as": "customer_initiated",
              "id": "269650473",
              "subject": "",
              "type": "conversation",
              "url": "https://intercom-survey-app.glitch.me/",
              "redacted": false
            },
            "contacts": [
              {
                "id": "5bc8f7ae2d96695c18a",
                "type": "lead"
              }
            ],
            "teammates": [
              {
                "id": "814860",
                "type": "admin"
              }
            ],
            "title": "Conversation Title",
            "admin_assignee_id": 814860,
            "team_assignee_id": null,
            "custom_attributes": {
              "issue_type": "Billing",
              "priority": "High"
            },
            "topics": {
              "type": "topic.list",
              "topics": [
                {
                  "type": "topic",
                  "name": "Example Topic 1",
                  "id": 839
                }
              ],
              "total_count": 1
            },
            "open": true,
            "state": "open",
            "read": true,
            "waiting_since": 64654125776,
            "snoozed_until": null,
            "tags": {
              "tags": [],
              "type": "tag.list"
            },
            "first_contact_reply": {
              "created_at": 1539897198,
              "type": "conversation",
              "url": "https://intercom-survey-app.glitch.me/"
            },
            "priority": "not_priority",
            "sla_applied": {
              "sla_name": "VIP customer <5m",
              "sla_status": "missed"
            },
            "conversation_rating": {
              "created_at": null,
              "contact": {
                "id": null,
                "type": null
              },
              "rating": null,
              "remark": null,
              "teammate": {
                "id": null,
                "type": null
              }
            },
            "statistics": {
              "time_to_assignment": 2310,
              "time_to_admin_reply": 2408,
              "time_to_first_close": 4915 ,
              "time_to_last_close": 5125,
              "median_time_to_reply": 321,
              "first_contact_reply_at": 1539897200,
              "first_assignment_at": 1539897200,
              "first_admin_reply_at": 1539897200,
              "first_close_at": 1539897200,
              "last_assignment_at": 1539897200,
              "last_assignment_admin_reply_at": 1539897200,
              "last_contact_reply_at": 1539897200,
              "last_admin_reply_at": 1539897200,
              "last_close_at": 1539897200,
              "last_closed_by": {
                "type": "admin",
                "id": "325432652",
                "name": "Tom Smith",
                "email": "tom@example.com"
              },
              "count_reopens": 3,
              "count_assignments": 2,
              "count_conversation_parts": 67
            },
            "conversation_parts": {
              "conversation_parts": [
                {
                  "assigned_to": null,
                  "attachments": [],
                  "author": {
                    "id": "815309",
                    "type": "bot"
                  },
                  "body": "<p>Test_App typically replies in a few hours.</p>",
                  "created_at": 1539897200,
                  "external_id": null,
                  "id": "2202737122",
                  "notified_at": 1539897200,
                  "part_type": "comment",
                  "type": "conversation_part",
                  "updated_at": 1539897200,
                  "redacted": false
                }
              ],
              "total_count": 67,
              "type": "conversation_part.list"
            }
          }
        },
        "links": {},
        "id": "notif_9cc0ef6e-3dfd-47a9-a715-be6cf19a273a",
        "topic": "conversation.updated",
        "delivery_status": "retry",
        "delivery_attempts": 2,
        "delivered_at": 0,
        "first_sent_at": 1692131395,
        "created_at": 1692131388
      }
    JSON
  end

  it_behaves_like "a replicator that may have a minimal body" do
    let(:body) { JSON.parse(<<~JSON) }
      {
        "type": "notification_event",
        "app_id": "vne310wv",
        "data": {
          "type": "notification_event_data",
          "item": {
            "type": "conversation",
            "id": "123",
            "created_at": 1539897198,
            "updated_at": 1540393270,
            "title": "Conversation Title",
            "admin_assignee_id": 814860,
            "team_assignee_id": null,
            "custom_attributes": {
              "issue_type": "Billing",
              "priority": "High"
            },
            "open": true,
            "state": "open",
            "read": true,
            "waiting_since": 64654125776,
            "snoozed_until": null,
            "priority": "not_priority",
            "sla_applied": {
              "sla_name": "VIP customer <5m",
              "sla_status": "missed"
            }
          }
        },
        "links": {},
        "id": null,
        "topic": "conversation.read",
        "delivery_status": null,
        "delivery_attempts": 1,
        "delivered_at": 0,
        "first_sent_at": 1710776797,
        "created_at": 1710776797,
        "self": null
      }
    JSON

    let(:archived_body) { JSON.parse(<<~JSON) }
      {
        "type": "notification_event",
        "app_id": "ol9hno6x",
        "data": {
          "type": "notification_event_data",
          "item": {
            "type": "conversation",
            "conversation_id": "456"
          }
        },
        "links": {},
        "id": "notif_26c802a6-774d-41d2-806a-fede50eb8246",
        "topic": "conversation.deleted",
        "delivery_status": "pending",
        "delivery_attempts": 1,
        "delivered_at": 0,
        "first_sent_at": 1710755503,
        "created_at": 1710755503,
        "self": null
      }
    JSON
    let(:other_bodies) { [archived_body] }
  end

  it_behaves_like "a replicator dependent on another", "intercom_marketplace_root_v1" do
    let(:no_dependencies_message) { "This integration requires Intercom Auth to sync" }
  end

  it_behaves_like "a replicator that can backfill" do
    before(:each) { Webhookdb::Intercom.page_size = 2 }

    let(:page1_response) { <<~JSON }
      {
        "type": "list",
        "data": [
          {
            "type": "conversation",
            "id": "123",
            "created_at": 1539897198,
            "updated_at": 1540393270,
            "source": {
              "attachments": [],
              "author": {
                "id": "5bc8f7421ae2d96695c18a",
                "type": "lead"
              },
              "body": "<p>Hi</p>",
              "delivered_as": "customer_initiated",
              "id": "269650473",
              "subject": "",
              "type": "conversation",
              "url": "https://intercom-survey-app.glitch.me/",
              "redacted": false
            },
            "contacts": [
              {
                "id": "5bc8f7ae2d96695c18a",
                "type": "lead"
              }
            ],
            "teammates": [
              {
                "id": "814860",
                "type": "admin"
              }
            ],
            "title": "Conversation Title",
            "admin_assignee_id": 814860,
            "team_assignee_id": null,
            "custom_attributes": {
              "issue_type": "Billing",
              "priority": "High"
            },
            "topics": {
              "type": "topic.list",
              "topics": [
                {
                  "type": "topic",
                  "name": "Example Topic 1",
                  "id": 839
                }
              ],
              "total_count": 1
            },
            "open": true,
            "state": "open",
            "read": true,
            "waiting_since": 64654125776,
            "snoozed_until": null,
            "tags": {
              "tags": [],
              "type": "tag.list"
            },
            "first_contact_reply": {
              "created_at": 1539897198,
              "type": "conversation",
              "url": "https://intercom-survey-app.glitch.me/"
            },
            "priority": "not_priority",
            "sla_applied": {
              "sla_name": "VIP customer <5m",
              "sla_status": "missed"
            },
            "conversation_rating": {
              "created_at": null,
              "contact": {
                "id": null,
                "type": null
              },
              "rating": null,
              "remark": null,
              "teammate": {
                "id": null,
                "type": null
              }
            },
            "statistics": {
              "time_to_assignment": 2310,
              "time_to_admin_reply": 2408,
              "time_to_first_close": 4915 ,
              "time_to_last_close": 5125,
              "median_time_to_reply": 321,
              "first_contact_reply_at": 1539897200,
              "first_assignment_at": 1539897200,
              "first_admin_reply_at": 1539897200,
              "first_close_at": 1539897200,
              "last_assignment_at": 1539897200,
              "last_assignment_admin_reply_at": 1539897200,
              "last_contact_reply_at": 1539897200,
              "last_admin_reply_at": 1539897200,
              "last_close_at": 1539897200,
              "last_closed_by": {
                "type": "admin",
                "id": "325432652",
                "name": "Tom Smith",
                "email": "tom@example.com"
              },
              "count_reopens": 3,
              "count_assignments": 2,
              "count_conversation_parts": 67
            },
            "conversation_parts": {
              "conversation_parts": [
                {
                  "assigned_to": null,
                  "attachments": [],
                  "author": {
                    "id": "815309",
                    "type": "bot"
                  },
                  "body": "<p>Test_App typically replies in a few hours.</p>",
                  "created_at": 1539897200,
                  "external_id": null,
                  "id": "2202737122",
                  "notified_at": 1539897200,
                  "part_type": "comment",
                  "type": "conversation_part",
                  "updated_at": 1539897200,
                  "redacted": false
                }
              ],
              "total_count": 67,
              "type": "conversation_part.list"
            }
          },
          {
            "type": "conversation",
            "id": "456",
            "created_at": 1539897198,
            "updated_at": 1540393270,
            "source": {
              "attachments": [],
              "author": {
                "id": "5bc8f7421ae2d96695c18a",
                "type": "lead"
              },
              "body": "<p>Hi</p>",
              "delivered_as": "customer_initiated",
              "id": "269650473",
              "subject": "",
              "type": "conversation",
              "url": "https://intercom-survey-app.glitch.me/",
              "redacted": false
            },
            "contacts": [
              {
                "id": "5bc8f7ae2d96695c18a",
                "type": "lead"
              }
            ],
            "teammates": [
              {
                "id": "814860",
                "type": "admin"
              }
            ],
            "title": "Conversation Title",
            "admin_assignee_id": 814860,
            "team_assignee_id": null,
            "custom_attributes": {
              "issue_type": "Billing",
              "priority": "High"
            },
            "topics": {
              "type": "topic.list",
              "topics": [
                {
                  "type": "topic",
                  "name": "Example Topic 1",
                  "id": 839
                }
              ],
              "total_count": 1
            },
            "open": true,
            "state": "open",
            "read": true,
            "waiting_since": 64654125776,
            "snoozed_until": null,
            "tags": {
              "tags": [],
              "type": "tag.list"
            },
            "first_contact_reply": {
              "created_at": 1539897198,
              "type": "conversation",
              "url": "https://intercom-survey-app.glitch.me/"
            },
            "priority": "not_priority",
            "sla_applied": {
              "sla_name": "VIP customer <5m",
              "sla_status": "missed"
            },
            "conversation_rating": {
              "created_at": null,
              "contact": {
                "id": null,
                "type": null
              },
              "rating": null,
              "remark": null,
              "teammate": {
                "id": null,
                "type": null
              }
            },
            "statistics": {
              "time_to_assignment": 2310,
              "time_to_admin_reply": 2408,
              "time_to_first_close": 4915 ,
              "time_to_last_close": 5125,
              "median_time_to_reply": 321,
              "first_contact_reply_at": 1539897200,
              "first_assignment_at": 1539897200,
              "first_admin_reply_at": 1539897200,
              "first_close_at": 1539897200,
              "last_assignment_at": 1539897200,
              "last_assignment_admin_reply_at": 1539897200,
              "last_contact_reply_at": 1539897200,
              "last_admin_reply_at": 1539897200,
              "last_close_at": 1539897200,
              "last_closed_by": {
                "type": "admin",
                "id": "325432652",
                "name": "Tom Smith",
                "email": "tom@example.com"
              },
              "count_reopens": 3,
              "count_assignments": 2,
              "count_conversation_parts": 67
            },
            "conversation_parts": {
              "conversation_parts": [
                {
                  "assigned_to": null,
                  "attachments": [],
                  "author": {
                    "id": "815309",
                    "type": "bot"
                  },
                  "body": "<p>Test_App typically replies in a few hours.</p>",
                  "created_at": 1539897200,
                  "external_id": null,
                  "id": "2202737122",
                  "notified_at": 1539897200,
                  "part_type": "comment",
                  "type": "conversation_part",
                  "updated_at": 1539897200,
                  "redacted": false
                }
              ],
              "total_count": 67,
              "type": "conversation_part.list"
            }
          }
        ],
        "total_count": 3,
        "pages": {
          "type": "pages",
          "next": {
            "page": 2,
            "starting_after": "intercom_pagination_token"
          },
          "page": 1,
          "per_page": 2,
          "total_pages": 2
        }
      }
    JSON
    let(:page2_response) { <<~JSON }
      {
        "type": "list",
        "data": [
          {
            "type": "conversation",
            "id": "789",
            "created_at": 1539897198,
            "updated_at": 1540393270,
            "source": {
              "attachments": [],
              "author": {
                "id": "5bc8f7421ae2d96695c18a",
                "type": "lead"
              },
              "body": "<p>Hi</p>",
              "delivered_as": "customer_initiated",
              "id": "269650473",
              "subject": "",
              "type": "conversation",
              "url": "https://intercom-survey-app.glitch.me/",
              "redacted": false
            },
            "contacts": [
              {
                "id": "5bc8f7ae2d96695c18a",
                "type": "lead"
              }
            ],
            "teammates": [
              {
                "id": "814860",
                "type": "admin"
              }
            ],
            "title": "Conversation Title",
            "admin_assignee_id": 814860,
            "team_assignee_id": null,
            "custom_attributes": {
              "issue_type": "Billing",
              "priority": "High"
            },
            "topics": {
              "type": "topic.list",
              "topics": [
                {
                  "type": "topic",
                  "name": "Example Topic 1",
                  "id": 839
                }
              ],
              "total_count": 1
            },
            "open": true,
            "state": "open",
            "read": true,
            "waiting_since": 64654125776,
            "snoozed_until": null,
            "tags": {
              "tags": [],
              "type": "tag.list"
            },
            "first_contact_reply": {
              "created_at": 1539897198,
              "type": "conversation",
              "url": "https://intercom-survey-app.glitch.me/"
            },
            "priority": "not_priority",
            "sla_applied": {
              "sla_name": "VIP customer <5m",
              "sla_status": "missed"
            },
            "conversation_rating": {
              "created_at": null,
              "contact": {
                "id": null,
                "type": null
              },
              "rating": null,
              "remark": null,
              "teammate": {
                "id": null,
                "type": null
              }
            },
            "statistics": {
              "time_to_assignment": 2310,
              "time_to_admin_reply": 2408,
              "time_to_first_close": 4915 ,
              "time_to_last_close": 5125,
              "median_time_to_reply": 321,
              "first_contact_reply_at": 1539897200,
              "first_assignment_at": 1539897200,
              "first_admin_reply_at": 1539897200,
              "first_close_at": 1539897200,
              "last_assignment_at": 1539897200,
              "last_assignment_admin_reply_at": 1539897200,
              "last_contact_reply_at": 1539897200,
              "last_admin_reply_at": 1539897200,
              "last_close_at": 1539897200,
              "last_closed_by": {
                "type": "admin",
                "id": "325432652",
                "name": "Tom Smith",
                "email": "tom@example.com"
              },
              "count_reopens": 3,
              "count_assignments": 2,
              "count_conversation_parts": 67
            },
            "conversation_parts": {
              "conversation_parts": [
                {
                  "assigned_to": null,
                  "attachments": [],
                  "author": {
                    "id": "815309",
                    "type": "bot"
                  },
                  "body": "<p>Test_App typically replies in a few hours.</p>",
                  "created_at": 1539897200,
                  "external_id": null,
                  "id": "2202737122",
                  "notified_at": 1539897200,
                  "part_type": "comment",
                  "type": "conversation_part",
                  "updated_at": 1539897200,
                  "redacted": false
                }
              ],
              "total_count": 67,
              "type": "conversation_part.list"
            }
          }
        ],
        "total_count": 3,
        "pages": {
          "type": "pages",
          "page": 2,
          "per_page": 2,
          "total_pages": 2
        }
      }
    JSON
    let(:expected_items_count) { 3 }

    let(:empty_response) { <<~JSON }
      {
        "type": "list",
        "data": [],
        "total_count": 0,
        "pages": {
          "type": "pages",
          "page": 1,
          "per_page": 10,
          "total_pages": 0
        }
      }
    JSON

    def insert_required_data_callback
      return lambda do |auth_svc|
        auth_svc.service_integration.update(backfill_key: "intercom_auth_token")
      end
    end

    def stub_service_requests
      return [
        stub_request(:get, "https://api.intercom.io/conversations?per_page=2").
            to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://api.intercom.io/conversations?per_page=2&starting_after=intercom_pagination_token").
            to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_empty_requests
      return [
        stub_request(:get, "https://api.intercom.io/conversations?per_page=2").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.intercom.io/conversations?per_page=2").
          to_return(status: 400, body: "uhh")
    end
  end

  it_behaves_like "a backfill replicator that requires credentials from a dependency" do
    let(:error_message) { /that the Intercom Auth integration has a valid Auth Token/ }
    def strip_auth(sint)
      sint.replicator.find_auth_integration.update(backfill_secret: "")
    end
  end

  describe "upserting" do
    let(:full_body) { JSON.parse(<<~JSON) }
      {
        "type": "conversation",
        "id": "123",
        "created_at": 1539897198,
        "updated_at": 1540393270,
        "title": "Conversation Title",
        "admin_assignee_id": 814860,
        "team_assignee_id": null,
        "custom_attributes": {
          "issue_type": "Billing",
          "priority": "High"
        },
        "open": true,
        "state": "open",
        "read": true,
        "waiting_since": 64654125776,
        "snoozed_until": null,
        "priority": "not_priority",
        "sla_applied": {
          "sla_name": "VIP customer <5m",
          "sla_status": "missed"
        }
      }
    JSON

    describe "handling a delete event" do
      let(:delete_event_body) { JSON.parse(<<~JSON) }
        {
          "type": "notification_event",
          "app_id": "ol9hno6x",
          "data": {
            "type": "notification_event_data",
            "item": {
              "type": "conversation",
              "conversation_id": "123"
            }
          },
          "links": {},
          "id": "notif_26c802a6-774d-41d2-806a-fede50eb8246",
          "topic": "conversation.deleted",
          "delivery_status": "pending",
          "delivery_attempts": 1,
          "delivered_at": 0,
          "first_sent_at": 1710755503,
          "created_at": 1710755503,
          "self": null
        }
      JSON

      before(:each) do
        org.prepare_database_connections
        svc.create_table
      end

      after(:each) do
        org.remove_related_database
      end

      it "will merge the delete info into an existing row" do
        svc.upsert_webhook_body(full_body)
        expect(svc.admin_dataset(&:first)).to include(
          intercom_id: "123",
          state: "open",
          read: true,
          created_at: match_time("2018-10-18 21:13:18Z"),
          updated_at: match_time("2018-10-24 15:01:10Z"),
          deleted_at: nil,
          data: hash_including("title" => "Conversation Title"),
        )
        svc.upsert_webhook_body(delete_event_body)
        expect(svc.admin_dataset(&:first)).to include(
          intercom_id: "123",
          state: "open",
          read: true,
          created_at: match_time("2018-10-18 21:13:18Z"),
          updated_at: match_time(:now),
          deleted_at: match_time(:now),
          data: hash_including("title" => "Conversation Title", "deleted" => true),
        )
      end
    end

    describe "handling contact attach/detach events" do
      let(:event_body) { JSON.parse(<<~JSON) }
        {
          "type": "notification_event",
          "app_id": "ol9hno6x",
          "data": {
            "type": "notification_event_data",
            "item": {
              "conversation": {
                "parts": [
                  {
                    "id": 21893097594,
                    "app_id": 1650250,
                    "conversation_id": 1886,
                    "message_thread_id": 2202171768,
                    "body": "",
                    "created_at": "2024-03-23T14:41:12.000Z",
                    "updated_at": "2024-03-23T14:41:12.000Z",
                    "user_id": "65416fc0d0a855567fbf14ea"
                  }
                ],
                "options": {
                  "expand_for_notification": true
                },
                "model": {
                  "id": 1886,
                  "user_id": "65416fc0d0a855567fbf14ea",
                  "app_id": 1650250,
                  "message_id": 2113316339,
                  "created_at": "2024-03-23T14:41:07.000Z",
                  "updated_at": "2024-03-23T14:41:12.000Z",
                  "read_at": "2024-03-23T14:41:12.000Z",
                  "latest_user_visible_comment_at": "2024-03-23T14:41:12.000Z",
                  "latest_admin_visible_comment_at": "2024-03-23T14:41:12.000Z",
                  "first_opened_at": "2024-03-23T14:41:12.000Z",
                  "first_user_comment_at": "2024-03-23T14:41:11.000Z",
                  "message_subclass_type": 3,
                  "deleted": false,
                  "original_user_id": "-1",
                  "dismissed": false,
                  "delivery_state": "delivered",
                  "sent_at": "2024-03-23T14:41:07.000Z",
                  "initiator_id": null,
                  "initiator_type": null,
                  "initial_channel": 8,
                  "current_channel": 8
                }
              },
              "contact": {
                "type": "contact",
                "id": "65446e1aaf142d1550cfd6d7",
                "workspace_id": "ol9hno6x",
                "external_id": "4f45dea4-3f26-4728-9be4-668997f97459",
                "role": "lead",
                "email": "support@webhookdb.com",
                "phone": null,
                "formatted_phone": null,
                "name": "Support",
                "avatar": null,
                "owner_id": null,
                "social_profiles": {
                  "type": "list",
                  "data": []
                },
                "has_hard_bounced": false,
                "marked_email_as_spam": false,
                "unsubscribed_from_emails": false,
                "created_at": "2023-11-03T03:50:50.437+00:00",
                "updated_at": "2024-03-23T14:23:03.486+00:00",
                "signed_up_at": null,
                "last_seen_at": null,
                "last_replied_at": "2024-03-04T19:44:02.000+00:00",
                "last_contacted_at": "2024-03-23T10:48:22.713+00:00",
                "last_email_opened_at": "2024-03-23T14:23:03.475+00:00",
                "last_email_clicked_at": null,
                "language_override": null,
                "browser": null,
                "browser_version": null,
                "browser_language": null,
                "os": null
              }
            }
          },
          "links": {},
          "id": "notif_13111f53-116a-410c-90f8-2b3cd9459797",
          "topic": "conversation.contact.attached",
          "delivery_status": "pending",
          "delivery_attempts": 1,
          "delivered_at": 0,
          "first_sent_at": 1711204872,
          "created_at": 1711204872,
          "self": null
        }
      JSON

      before(:each) do
        org.prepare_database_connections
        svc.create_table
      end

      after(:each) do
        org.remove_related_database
      end

      it "skips the upsert" do
        svc.upsert_webhook_body(event_body)
        expect(svc.admin_dataset(&:all)).to be_empty
      end
    end
  end

  describe "state machine calculation" do
    describe "calculate_backfill_state_machine" do
      it "prompts for dependencies" do
        sint.update(depends_on: nil)
        root.destroy
        sm = sint.replicator.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          output: match("This integration requires Intercom Auth to sync"),
        )
      end

      it "succeeds and prints a success response if the dependency is set" do
        sm = sint.replicator.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          complete: true,
          output: match("start replicating Intercom Conversation"),
        )
      end
    end
  end

  describe "find_auth_integration" do
    it "can find parent auth integration" do
      auth_parent = sint.replicator.find_auth_integration
      expect(auth_parent.id).to eq(root.id)
    end

    it "returns error if no auth parent present" do
      sint.depends_on = nil
      expect do
        sint.replicator.find_auth_integration
      end.to raise_error(Webhookdb::Replicator::CredentialsMissing)
    end
  end

  describe "_fetch_backfill_page" do
    before(:each) do
      Webhookdb::Intercom.page_size = 20
    end

    it "ignores 'api_plan_restricted' error" do
      error_body = {
        "type" => "error.list",
        "request_id" => "001io5rapr5ilb5s15c0",
        "errors" => [
          {"code" => "api_plan_restricted",
           "message" => "Active subscription needed.",},
        ],
      }.to_json
      stub_error_request = stub_request(:get, "https://api.intercom.io/conversations?per_page=20").
        to_return(status: 403, body: error_body, headers: {"Content-Type" => "application/json"})

      page, pagination_token = svc._fetch_backfill_page(nil, last_backfilled: nil)
      expect(page).to eq([])
      expect(pagination_token).to be_nil
      expect(stub_error_request).to have_been_made
    end

    it "emits a developer alert on a token_suspended 401", :async do
      error_body = {
        type: "error.list",
        request_id: "002d0qq7vsu5q3c6el80",
        errors: [{code: "token_suspended", message: "Unauthorized token, suspended application"}],
      }.to_json
      stub_error_request = stub_request(:get, "https://api.intercom.io/conversations?per_page=20").
        to_return(status: 401, body: error_body, headers: {"Content-Type" => "application/json"})

      expect do
        page, pagination_token = svc._fetch_backfill_page(nil, last_backfilled: nil)
        expect(page).to eq([])
        expect(pagination_token).to be_nil
        expect(stub_error_request).to have_been_made
      end.to publish("webhookdb.developeralert.emitted").with_payload(
        contain_exactly(
          {
            "subsystem" => "Intercom Workspace Closed Error",
            "emoji" => ":hook:",
            "fallback" => /From a console/,
            "fields" => have_length(3),
          },
        ),
      )
    end

    it "raises other errors" do
      error_body = {
        type: "error.list",
        request_id: "abc123",
        errors: [nil, [], [{code: "whatever"}]].sample,
      }.to_json
      stub_error_request = stub_request(:get, "https://api.intercom.io/conversations?per_page=20").
        to_return(status: [401, 404].sample, body: error_body, headers: {"Content-Type" => "application/json"})

      expect do
        svc._fetch_backfill_page(nil, last_backfilled: nil)
      end.to raise_error(Webhookdb::Http::Error, /"request_id":"abc123"/)
      expect(stub_error_request).to have_been_made
    end
  end
end
