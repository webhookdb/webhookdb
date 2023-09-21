# frozen_string_literal: true

require "support/shared_examples_for_replicators"
require "webhookdb/intercom"

RSpec.describe Webhookdb::Replicator::IntercomConversationV1, :db do
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }
  let(:root) { fac.create(service_name: "intercom_marketplace_root_v1", backfill_key: "intercom_auth_token") }
  let(:sint) { fac.depending_on(root).create(service_name: "intercom_conversation_v1").refresh }
  let(:svc) { sint.replicator }

  it_behaves_like "a replicator", "intercom_conversation_v1" do
    let(:body) do
      JSON.parse(<<~J)
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
      J
    end
  end

  it_behaves_like "a replicator that deals with resources and wrapped events", "intercom_conversation_v1" do
    let(:resource_json) { resource_in_envelope_json.dig("data", "item") }
    let(:resource_in_envelope_json) do
      JSON.parse(<<~J)
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
      J
    end
  end

  it_behaves_like "a replicator dependent on another", "intercom_conversation_v1", "intercom_marketplace_root_v1" do
    let(:no_dependencies_message) { "This integration requires Intercom Auth to sync" }
  end

  it_behaves_like "a replicator that can backfill", "intercom_conversation_v1" do
    before(:each) { Webhookdb::Intercom.page_size = 2 }

    let(:page1_response) do
      <<~R
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
            },#{' '}
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
      R
    end
    let(:page2_response) do
      <<~R
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
      R
    end
    let(:expected_items_count) { 3 }

    let(:empty_response) do
      <<~R
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
      R
    end

    def insert_required_data_callback
      return lambda do |auth_svc|
        auth_svc.service_integration.update(backfill_key: "intercom_auth_token")
      end
    end

    def stub_service_requests
      return [
        stub_request(:get, "https://api.intercom.io/conversations?per_page=2&starting_after=").
            to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://api.intercom.io/conversations?per_page=2&starting_after=intercom_pagination_token").
            to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_empty_requests
      return [
        stub_request(:get, "https://api.intercom.io/conversations?per_page=2&starting_after=").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.intercom.io/conversations?per_page=2&starting_after=").
          to_return(status: 503, body: "uhh")
    end
  end

  it_behaves_like "a backfill replicator that requires credentials from a dependency", "intercom_conversation_v1" do
    let(:error_message) { /that the Intercom Auth integration has a valid Auth Token/ }
    def strip_auth(sint)
      sint.replicator.find_auth_integration.update(backfill_secret: "")
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
    it "ignores 'api_plan_restricted' error" do
      Webhookdb::Intercom.page_size = 20
      error_body = {
        "type" => "error.list",
        "request_id" => "001io5rapr5ilb5s15c0",
        "errors" => [
          {"code" => "api_plan_restricted",
           "message" => "Active subscription needed.",},
        ],
      }.to_json
      stub_error_request = stub_request(:get, "https://api.intercom.io/conversations?per_page=20&starting_after=").
        to_return(status: 403, body: error_body, headers: {"Content-Type" => "application/json"})

      page, pagination_token = svc._fetch_backfill_page(nil)
      expect(page).to eq([])
      expect(pagination_token).to be_nil
      expect(stub_error_request).to have_been_made
    end
  end
end
