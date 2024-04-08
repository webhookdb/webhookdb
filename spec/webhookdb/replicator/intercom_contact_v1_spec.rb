# frozen_string_literal: true

require "support/shared_examples_for_replicators"
require "webhookdb/intercom"

RSpec.describe Webhookdb::Replicator::IntercomContactV1, :db do
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }
  let(:root) { fac.create(service_name: "intercom_marketplace_root_v1", backfill_key: "intercom_auth_token") }
  let(:sint) { fac.depending_on(root).create(service_name: "intercom_contact_v1").refresh }
  let(:svc) { sint.replicator }

  it_behaves_like "a replicator", "intercom_contact_v1" do
    let(:body) { JSON.parse(<<~JSON) }
      {
        "type": "contact",
        "id": "64d14669156d93e1e18f6a17",
        "workspace_id": "vne310wv",
        "external_id": null,
        "role": "user",
        "email": "alivia@example.com",
        "phone": null,
        "name": null,
        "avatar": null,
        "owner_id": null,
        "social_profiles": {
          "type": "list",
          "data": []
        },
        "has_hard_bounced": false,
        "marked_email_as_spam": false,
        "unsubscribed_from_emails": false,
        "created_at": 1691436649,
        "updated_at": 1691436649,
        "signed_up_at": null,
        "last_seen_at": null,
        "last_replied_at": null,
        "last_contacted_at": null,
        "last_email_opened_at": null,
        "last_email_clicked_at": null,
        "language_override": null,
        "browser": null,
        "browser_version": null,
        "browser_language": null,
        "os": null,
        "location": {
          "type": "location",
          "country": null,
          "region": null,
          "city": null,
          "country_code": null,
          "continent_code": null
        },
        "android_app_name": null,
        "android_app_version": null,
        "android_device": null,
        "android_os_version": null,
        "android_sdk_version": null,
        "android_last_seen_at": null,
        "ios_app_name": null,
        "ios_app_version": null,
        "ios_device": null,
        "ios_os_version": null,
        "ios_sdk_version": null,
        "ios_last_seen_at": null,
        "custom_attributes": {},
        "tags": {
          "type": "list",
          "data": [
            {
              "id": "8362462",
              "type": "tag",
              "url": "/tags/8362462"
            }
          ],
          "url": "/contacts/64d14669156d93e1e18f6a17/tags",
          "total_count": 1,
          "has_more": false
        },
        "notes": {
          "type": "list",
          "data": [],
          "url": "/contacts/64d14669156d93e1e18f6a17/notes",
          "total_count": 0,
          "has_more": false
        },
        "companies": {
          "type": "list",
          "data": [],
          "url": "/contacts/64d14669156d93e1e18f6a17/companies",
          "total_count": 0,
          "has_more": false
        },
        "opted_out_subscription_types": {
          "type": "list",
          "data": [],
          "url": "/contacts/64d14669156d93e1e18f6a17/subscriptions",
          "total_count": 0,
          "has_more": false
        },
        "opted_in_subscription_types": {
          "type": "list",
          "data": [],
          "url": "/contacts/64d14669156d93e1e18f6a17/subscriptions",
          "total_count": 0,
          "has_more": false
        },
        "utm_campaign": null,
        "utm_content": null,
        "utm_medium": null,
        "utm_source": null,
        "utm_term": null,
        "referrer": null,
        "sms_consent": false,
        "unsubscribed_from_sms": false
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

  it_behaves_like "a replicator that deals with resources and wrapped events", "intercom_contact_v1" do
    let(:resource_json) { resource_in_envelope_json.dig("data", "item") }
    let(:resource_in_envelope_json) { JSON.parse(<<~JSON) }
      {
        "type": "notification_event",
        "app_id": "vne310wv",
        "data": {
          "type": "notification_event_data",
          "item": {
            "type": "contact",
            "id": "64dbc8be576618069c4e0560",
            "workspace_id": "vne310wv",
            "external_id": "12342353",
            "role": "user",
            "email": "nardwuar@example.com",
            "phone": null,
            "name": "Nardwuar",
            "avatar": null,
            "owner_id": null,
            "social_profiles": {
              "type": "list",
              "data": []
            },
            "has_hard_bounced": false,
            "marked_email_as_spam": false,
            "unsubscribed_from_emails": false,
            "created_at": "2023-08-15T18:49:35.016+00:00",
            "updated_at": "2023-08-15T20:29:47.988+00:00",
            "signed_up_at": null,
            "last_seen_at": null,
            "last_replied_at": null,
            "last_contacted_at": null,
            "last_email_opened_at": null,
            "last_email_clicked_at": null,
            "language_override": null,
            "browser": null,
            "browser_version": null,
            "browser_language": null,
            "os": null,
            "location": {
              "type": "location",
              "country": null,
              "region": null,
              "city": null,
              "country_code": null,
              "continent_code": null
            },
            "android_app_name": null,
            "android_app_version": null,
            "android_device": null,
            "android_os_version": null,
            "android_sdk_version": null,
            "android_last_seen_at": null,
            "ios_app_name": null,
            "ios_app_version": null,
            "ios_device": null,
            "ios_os_version": null,
            "ios_sdk_version": null,
            "ios_last_seen_at": null,
            "custom_attributes": {},
            "tags": {
              "type": "list",
              "data": [],
              "url": "/contacts/64dbc8be576618069c4e0560/tags",
              "total_count": 0,
              "has_more": false
            },
            "notes": {
              "type": "list",
              "data": [],
              "url": "/contacts/64dbc8be576618069c4e0560/notes",
              "total_count": 0,
              "has_more": false
            },
            "companies": {
              "type": "list",
              "data": [],
              "url": "/contacts/64dbc8be576618069c4e0560/companies",
              "total_count": 0,
              "has_more": false
            },
            "opted_out_subscription_types": {
              "type": "list",
              "data": [],
              "url": "/contacts/64dbc8be576618069c4e0560/subscriptions",
              "total_count": 0,
              "has_more": false
            },
            "opted_in_subscription_types": {
              "type": "list",
              "data": [],
              "url": "/contacts/64dbc8be576618069c4e0560/subscriptions",
              "total_count": 0,
              "has_more": false
            },
            "utm_campaign": null,
            "utm_content": null,
            "utm_medium": null,
            "utm_source": null,
            "utm_term": null,
            "referrer": null,
            "sms_consent": false,
            "unsubscribed_from_sms": false
          }
        },
        "links": {},
        "id": "notif_9cc0ef6e-3dfd-47a9-a715-be6cf19a273a",
        "topic": "contact.user.updated",
        "delivery_status": "retry",
        "delivery_attempts": 2,
        "delivered_at": 0,
        "first_sent_at": 1692131395,
        "created_at": 1692131388
      }
    JSON
  end

  it_behaves_like "a replicator that may have a minimal body", "intercom_contact_v1" do
    let(:body) { JSON.parse(<<~JSON) }
      {
        "type": "notification_event",
        "app_id": "ol9hno6x",
        "data": {
          "type": "notification_event_data",
          "item": {
            "id": "65f642bf674b9af4e9e46dd1",
            "type": "contact",
            "deleted": true
          }
        },
        "links": {},
        "id": "notif_19964a4b-1fc6-4770-967c-20374963a052",
        "topic": "contact.deleted",
        "delivery_status": "pending",
        "delivery_attempts": 1,
        "delivered_at": 0,
        "first_sent_at": 1710639325,
        "created_at": 1710639325,
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
            "id": "65f72703f2f977e25ba4330d",
            "external_id": null,
            "type": "contact",
            "archived": true
          }
        },
        "links": {},
        "id": "notif_633c931a-9a1c-4844-a733-aaa637df0f84",
        "topic": "contact.archived",
        "delivery_status": "pending",
        "delivery_attempts": 1,
        "delivered_at": 0,
        "first_sent_at": 1710696301,
        "created_at": 1710696300,
        "self": null
      }
    JSON
    let(:other_bodies) { [archived_body] }
  end

  it_behaves_like "a replicator dependent on another", "intercom_contact_v1", "intercom_marketplace_root_v1" do
    let(:no_dependencies_message) { "This integration requires Intercom Auth to sync" }
  end

  it_behaves_like "a replicator that can backfill", "intercom_contact_v1" do
    before(:each) { Webhookdb::Intercom.page_size = 2 }

    let(:page1_response) { <<~JSON }
      {
        "type": "list",
        "data": [
          {
            "type": "contact",
            "id": "64d14668156d93e1e18f6a13",
            "workspace_id": "vne310wv",
            "external_id": null,
            "role": "user",
            "email": "aria@example.com",
            "phone": null,
            "name": null,
            "avatar": null,
            "owner_id": null,
            "social_profiles": {
              "type": "list",
              "data": []
            },
            "has_hard_bounced": false,
            "marked_email_as_spam": false,
            "unsubscribed_from_emails": false,
            "created_at": 1691436648,
            "updated_at": 1691436648,
            "signed_up_at": null,
            "last_seen_at": null,
            "last_replied_at": null,
            "last_contacted_at": null,
            "last_email_opened_at": null,
            "last_email_clicked_at": null,
            "language_override": null,
            "browser": null,
            "browser_version": null,
            "browser_language": null,
            "os": null,
            "location": {
              "type": "location",
              "country": null,
              "region": null,
              "city": null,
              "country_code": null,
              "continent_code": null
            },
            "android_app_name": null,
            "android_app_version": null,
            "android_device": null,
            "android_os_version": null,
            "android_sdk_version": null,
            "android_last_seen_at": null,
            "ios_app_name": null,
            "ios_app_version": null,
            "ios_device": null,
            "ios_os_version": null,
            "ios_sdk_version": null,
            "ios_last_seen_at": null,
            "custom_attributes": {},
            "tags": {
              "type": "list",
              "data": [
                {
                  "id": "8362462",
                  "type": "tag",
                  "url": "/tags/8362462"
                }
              ],
              "url": "/contacts/64d14668156d93e1e18f6a13/tags",
              "total_count": 1,
              "has_more": false
            },
            "notes": {
              "type": "list",
              "data": [],
              "url": "/contacts/64d14668156d93e1e18f6a13/notes",
              "total_count": 0,
              "has_more": false
            },
            "companies": {
              "type": "list",
              "data": [],
              "url": "/contacts/64d14668156d93e1e18f6a13/companies",
              "total_count": 0,
              "has_more": false
            },
            "opted_out_subscription_types": {
              "type": "list",
              "data": [],
              "url": "/contacts/64d14668156d93e1e18f6a13/subscriptions",
              "total_count": 0,
              "has_more": false
            },
            "opted_in_subscription_types": {
              "type": "list",
              "data": [],
              "url": "/contacts/64d14668156d93e1e18f6a13/subscriptions",
              "total_count": 0,
              "has_more": false
            },
            "utm_campaign": null,
            "utm_content": null,
            "utm_medium": null,
            "utm_source": null,
            "utm_term": null,
            "referrer": null,
            "sms_consent": false,
            "unsubscribed_from_sms": false
          },
          {
            "type": "contact",
            "id": "64d14668156d93e1e18f6a14",
            "workspace_id": "vne310wv",
            "external_id": null,
            "role": "user",
            "email": "damian@example.com",
            "phone": null,
            "name": null,
            "avatar": null,
            "owner_id": null,
            "social_profiles": {
              "type": "list",
              "data": []
            },
            "has_hard_bounced": false,
            "marked_email_as_spam": false,
            "unsubscribed_from_emails": false,
            "created_at": 1691436648,
            "updated_at": 1691436648,
            "signed_up_at": null,
            "last_seen_at": null,
            "last_replied_at": null,
            "last_contacted_at": null,
            "last_email_opened_at": null,
            "last_email_clicked_at": null,
            "language_override": null,
            "browser": null,
            "browser_version": null,
            "browser_language": null,
            "os": null,
            "location": {
              "type": "location",
              "country": null,
              "region": null,
              "city": null,
              "country_code": null,
              "continent_code": null
            },
            "android_app_name": null,
            "android_app_version": null,
            "android_device": null,
            "android_os_version": null,
            "android_sdk_version": null,
            "android_last_seen_at": null,
            "ios_app_name": null,
            "ios_app_version": null,
            "ios_device": null,
            "ios_os_version": null,
            "ios_sdk_version": null,
            "ios_last_seen_at": null,
            "custom_attributes": {},
            "tags": {
              "type": "list",
              "data": [
                {
                  "id": "8362462",
                  "type": "tag",
                  "url": "/tags/8362462"
                }
              ],
              "url": "/contacts/64d14668156d93e1e18f6a14/tags",
              "total_count": 1,
              "has_more": false
            },
            "notes": {
              "type": "list",
              "data": [],
              "url": "/contacts/64d14668156d93e1e18f6a14/notes",
              "total_count": 0,
                  "has_more": false
                },
                "companies": {
                  "type": "list",
                  "data": [],
                  "url": "/contacts/64d14668156d93e1e18f6a14/companies",
                  "total_count": 0,
                  "has_more": false
                },
                "opted_out_subscription_types": {
                  "type": "list",
                  "data": [],
                  "url": "/contacts/64d14668156d93e1e18f6a14/subscriptions",
                  "total_count": 0,
                  "has_more": false
                },
                "opted_in_subscription_types": {
                  "type": "list",
                  "data": [],
                  "url": "/contacts/64d14668156d93e1e18f6a14/subscriptions",
                  "total_count": 0,
                  "has_more": false
                },
                "utm_campaign": null,
                "utm_content": null,
                "utm_medium": null,
                "utm_source": null,
                "utm_term": null,
                "referrer": null,
                "sms_consent": false,
                "unsubscribed_from_sms": false
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
            "type": "contact",
            "id": "64d14669156d93e1e18f6a17",
            "workspace_id": "vne310wv",
            "external_id": null,
            "role": "user",
            "email": "alivia@example.com",
            "phone": null,
            "name": null,
            "avatar": null,
            "owner_id": null,
            "social_profiles": {
              "type": "list",
              "data": []
            },
            "has_hard_bounced": false,
            "marked_email_as_spam": false,
            "unsubscribed_from_emails": false,
            "created_at": 1691436649,
            "updated_at": 1691436649,
            "signed_up_at": null,
            "last_seen_at": null,
            "last_replied_at": null,
            "last_contacted_at": null,
            "last_email_opened_at": null,
            "last_email_clicked_at": null,
            "language_override": null,
            "browser": null,
            "browser_version": null,
            "browser_language": null,
            "os": null,
            "location": {
              "type": "location",
              "country": null,
              "region": null,
              "city": null,
              "country_code": null,
              "continent_code": null
            },
            "android_app_name": null,
            "android_app_version": null,
            "android_device": null,
            "android_os_version": null,
            "android_sdk_version": null,
            "android_last_seen_at": null,
            "ios_app_name": null,
            "ios_app_version": null,
            "ios_device": null,
            "ios_os_version": null,
            "ios_sdk_version": null,
            "ios_last_seen_at": null,
            "custom_attributes": {},
            "tags": {
              "type": "list",
              "data": [
                {
                  "id": "8362462",
                  "type": "tag",
                  "url": "/tags/8362462"
                }
              ],
              "url": "/contacts/64d14669156d93e1e18f6a17/tags",
              "total_count": 1,
              "has_more": false
            },
            "notes": {
              "type": "list",
              "data": [],
              "url": "/contacts/64d14669156d93e1e18f6a17/notes",
              "total_count": 0,
              "has_more": false
            },
            "companies": {
              "type": "list",
              "data": [],
              "url": "/contacts/64d14669156d93e1e18f6a17/companies",
              "total_count": 0,
              "has_more": false
            },
            "opted_out_subscription_types": {
              "type": "list",
              "data": [],
              "url": "/contacts/64d14669156d93e1e18f6a17/subscriptions",
              "total_count": 0,
              "has_more": false
            },
            "opted_in_subscription_types": {
              "type": "list",
              "data": [],
              "url": "/contacts/64d14669156d93e1e18f6a17/subscriptions",
              "total_count": 0,
              "has_more": false
            },
            "utm_campaign": null,
            "utm_content": null,
            "utm_medium": null,
            "utm_source": null,
            "utm_term": null,
            "referrer": null,
            "sms_consent": false,
            "unsubscribed_from_sms": false
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
        stub_request(:get, "https://api.intercom.io/contacts?per_page=2").
            to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://api.intercom.io/contacts?per_page=2&starting_after=intercom_pagination_token").
            to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_empty_requests
      return [
        stub_request(:get, "https://api.intercom.io/contacts?per_page=2").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.intercom.io/contacts?per_page=2").
          to_return(status: 400, body: "uhh")
    end
  end

  it_behaves_like "a backfill replicator that requires credentials from a dependency", "intercom_contact_v1" do
    let(:error_message) { /that the Intercom Auth integration has a valid Auth Token/ }
    def strip_auth(sint)
      sint.replicator.find_auth_integration.update(backfill_secret: "")
    end
  end

  describe "upserting" do
    let(:full_body) { JSON.parse(<<~JSON) }
      {
        "type": "contact",
        "id": "64d14669156d93e1e18f6a17",
        "external_id": "abc",
        "email": "alivia@example.com",
        "created_at": 1691436649,
        "updated_at": 1691436650
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
              "id": "64d14669156d93e1e18f6a17",
              "type": "contact",
              "deleted": true
            }
          },
          "links": {},
          "id": "notif_19964a4b-1fc6-4770-967c-20374963a052",
          "topic": "contact.deleted",
          "delivery_status": "pending",
          "delivery_attempts": 1,
          "delivered_at": 0,
          "first_sent_at": 1710639325,
          "created_at": 1710639325,
          "self": null
        }
      JSON

      it "will merge the delete info into an existing row" do
        org.prepare_database_connections
        svc.create_table
        svc.upsert_webhook_body(full_body)
        expect(svc.admin_dataset(&:first)).to include(
          intercom_id: "64d14669156d93e1e18f6a17",
          external_id: "abc",
          email: "alivia@example.com",
          created_at: match_time("2023-08-07 19:30:49Z"),
          updated_at: match_time("2023-08-07 19:30:50Z"),
          deleted_at: nil,
          archived_at: nil,
          data: hash_including("email" => "alivia@example.com"),
        )
        svc.upsert_webhook_body(delete_event_body)
        expect(svc.admin_dataset(&:first)).to include(
          intercom_id: "64d14669156d93e1e18f6a17",
          external_id: "abc",
          email: "alivia@example.com",
          created_at: match_time("2023-08-07 19:30:49Z"),
          updated_at: match_time(:now),
          deleted_at: match_time(:now),
          archived_at: nil,
          data: hash_including("email" => "alivia@example.com", "deleted" => true),
        )
      ensure
        org.remove_related_database
      end
    end

    describe "handling an archive event" do
      let(:archive_event_body) { JSON.parse(<<~JSON) }
        {
          "type": "notification_event",
          "app_id": "ol9hno6x",
          "data": {
            "type": "notification_event_data",
            "item": {
              "id": "64d14669156d93e1e18f6a17",
              "external_id": null,
              "type": "contact",
              "archived": true
            }
          },
          "links": {},
          "id": "notif_633c931a-9a1c-4844-a733-aaa637df0f84",
          "topic": "contact.archived",
          "delivery_status": "pending",
          "delivery_attempts": 1,
          "delivered_at": 0,
          "first_sent_at": 1710696301,
          "created_at": 1710696300,
          "self": null
        }
      JSON

      it "will merge the archived info into an existing row" do
        org.prepare_database_connections
        svc.create_table
        svc.upsert_webhook_body(full_body)
        expect(svc.admin_dataset(&:first)).to include(
          intercom_id: "64d14669156d93e1e18f6a17",
          external_id: "abc",
          email: "alivia@example.com",
          created_at: match_time("2023-08-07 19:30:49Z"),
          updated_at: match_time("2023-08-07 19:30:50Z"),
          deleted_at: nil,
          archived_at: nil,
          data: hash_including("email" => "alivia@example.com"),
        )
        svc.upsert_webhook_body(archive_event_body)
        expect(svc.admin_dataset(&:first)).to include(
          intercom_id: "64d14669156d93e1e18f6a17",
          external_id: "abc",
          email: "alivia@example.com",
          created_at: match_time("2023-08-07 19:30:49Z"),
          updated_at: match_time(:now),
          deleted_at: nil,
          archived_at: match_time(:now),
          data: hash_including("email" => "alivia@example.com", "archived" => true),
        )
      ensure
        org.remove_related_database
      end
    end

    describe "handling an unsubscribe event" do
      let(:archive_event_body) { JSON.parse(<<~JSON) }
        {
          "type": "notification_event",
          "app_id": "12345",
          "data": {
            "type": "notification_event_data",
            "item": {
              "type": "contact_unsubscribe",
              "contact": {
                "type": "contact",
                "id": "64d14669156d93e1e18f6a17",
                "workspace_id": "44444",
                "external_id": "1922",
                "role": "user",
                "email": "info@abc.com",
                "phone": null,
                "marked_email_as_spam": false,
                "unsubscribed_from_emails": true,
                "created_at": "2023-11-02T21:18:23.595+00:00",
                "updated_at": "2024-04-02T21:22:22.670+00:00",
                "signed_up_at": "2023-11-02T21:19:21.000+00:00"
              },
              "created_at": 1712092942
            }
          },
          "links": {},
          "id": "notif_6e4f9405-02df-439f-9f3b-e2a775cd385c",
          "topic": "contact.unsubscribed",
          "delivery_status": "pending",
          "delivery_attempts": 1,
          "delivered_at": 0,
          "first_sent_at": 1712092942,
          "created_at": 1712092942,
          "self": null
        }
      JSON

      it "replaces an existing row" do
        org.prepare_database_connections
        svc.create_table
        svc.upsert_webhook_body(full_body)
        expect(svc.admin_dataset(&:first)).to include(
          intercom_id: "64d14669156d93e1e18f6a17",
          external_id: "abc",
        )
        svc.upsert_webhook_body(archive_event_body)
        expect(svc.admin_dataset(&:first)).to include(
          intercom_id: "64d14669156d93e1e18f6a17",
          external_id: "1922",
        )
      ensure
        org.remove_related_database
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
          output: match("start replicating Intercom Contact"),
        )
      end
    end
  end

  describe "mixin methods" do
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
end
