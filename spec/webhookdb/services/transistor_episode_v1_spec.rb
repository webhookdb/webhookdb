# frozen_string_literal: true

require "support/shared_examples_for_services"

RSpec.describe Webhookdb::Services::TransistorEpisodeV1, :db do
  before(:each) do
    stub_request(:get, %r{^https://api.transistor.fm/v1/analytics/episodes/\d+$}).
      to_return(
        status: 200,
        headers: {"Content-Type" => "application/json"},
        body: {
          data: {
            id: "1",
            type: "episode_analytics",
            attributes: {},
          },
        }.to_json,
      )
    allow(Kernel).to receive(:sleep)
  end

  it_behaves_like "a service implementation", "transistor_episode_v1" do
    let(:body) do
      JSON.parse(<<~J)
        {
           "data":{
              "id":"655205",
              "type":"episode",
              "attributes":{
                 "title":"THE SHOW",
                 "number":1,
                 "season":1,
                 "status":"published",
                 "published_at":"2021-09-20T10:51:45.707-07:00",
                 "duration":236,
                 "explicit":false,
                 "keywords":"",
                 "alternate_url":"",
                 "media_url":"https://media.transistor.fm/70562b4e/83984906.mp3",
                 "image_url":null,
                 "author":"",
                 "summary":"readgssfdctwadg",
                 "description":"",
                 "created_at":"2021-09-20T10:06:08.582-07:00",
                 "updated_at":"2021-09-20T10:51:45.708-07:00",
                 "formatted_published_at":"September 20, 2021",
                 "duration_in_mmss":"03:56",
                 "share_url":"https://share.transistor.fm/s/70562b4e",
                 "formatted_summary":"readgssfdctwadg",
                 "audio_processing":false,
                 "type":"full",
                 "email_notifications":null
              },
              "relationships":{
                 "show":{
                    "data":{
                       "id":"24204",
                       "type":"show"
                    }
                 }
              }
           }
        }
      J
    end
    let(:expected_data) { body }
  end

  it_behaves_like "a service implementation that prevents overwriting new data with old", "transistor_episode_v1" do
    let(:old_body) do
      JSON.parse(<<~J)
        {
           "data":{
              "id":"655205",
              "type":"episode",
              "attributes":{
                 "title":"THE SHOW",
                 "number":1,
                 "season":1,
                 "status":"published",
                 "published_at":"2021-09-20T10:51:45.707-07:00",
                 "duration":236,
                 "explicit":false,
                 "keywords":"",
                 "alternate_url":"",
                 "media_url":"https://media.transistor.fm/70562b4e/83984906.mp3",
                 "image_url":null,
                 "author":"",
                 "summary":"readgssfdctwadg",
                 "description":"",
                 "created_at":"2021-09-20T10:06:08.582-07:00",
                 "updated_at":"2021-09-20T10:51:45.708-07:00",
                 "formatted_published_at":"September 20, 2021",
                 "duration_in_mmss":"03:56",
                 "share_url":"https://share.transistor.fm/s/70562b4e",
                 "formatted_summary":"readgssfdctwadg",
                 "audio_processing":false,
                 "type":"full",
                 "email_notifications":null
              },
              "relationships":{
                 "show":{
                    "data":{
                       "id":"24204",
                       "type":"show"
                    }
                 }
              }
           }
        }
      J
    end
    let(:new_body) do
      JSON.parse(<<~J)
        {
            "data":{
               "id":"655205",
               "type":"episode",
               "attributes":{
                  "title":"New title ",
                  "number":1,
                  "season":1,
                  "status":"published",
                  "published_at":"2021-09-20T10:51:45.707-07:00",
                  "duration":236,
                  "explicit":false,
                  "keywords":"",
                  "alternate_url":"",
                  "media_url":"https://media.transistor.fm/70562b4e/83984906.mp3",
                  "image_url":null,
                  "author":"",
                  "summary":"new summary",
                  "description":"",
                  "created_at":"2021-09-20T10:06:08.582-07:00",
                  "updated_at":"2021-09-22T10:51:45.708-07:00",
                  "formatted_published_at":"September 20, 2021",
                  "duration_in_mmss":"03:56",
                  "share_url":"https://share.transistor.fm/s/70562b4e",
                  "formatted_summary":"readgssfdctwadg",
                  "audio_processing":false,
                  "type":"full",
                  "email_notifications":null
               },
               "relationships":{
                  "show":{
                     "data":{
                        "id":"24204",
                        "type":"show"
                     }
                  }
               }
            }
        }
      J
    end
  end

  it_behaves_like "a service implementation that verifies backfill secrets" do
    let(:correct_creds_sint) do
      Webhookdb::Fixtures.service_integration.create(
        service_name: "transistor_episode_v1",
        backfill_key: "bfkey",
      )
    end
    let(:incorrect_creds_sint) do
      Webhookdb::Fixtures.service_integration.create(
        service_name: "transistor_episode_v1",
        backfill_key: "bfkey_wrong",
      )
    end

    let(:success_body) do
      <<~R
        {
          "data": [],
          "meta": {}
        }
      R
    end
    def stub_service_request
      return stub_request(:get, "https://api.transistor.fm/v1/episodes").
          with(headers: {"X-Api-Key" => "bfkey"}).
          to_return(status: 200, body: success_body, headers: {})
    end

    def stub_service_request_error
      stub_request(:get, "https://api.transistor.fm/v1/episodes").
        with(headers: {"X-Api-Key" => "bfkey_wrong"}).
        to_return(status: 401, body: "", headers: {})
    end
  end

  it_behaves_like "a service implementation that can backfill", "transistor_episode_v1" do
    let(:page1_response) do
      <<~R
        {
           "data":[
              {
                 "id":"1",
                 "type":"episode",
                 "attributes":{
                    "title":"How To Roast Coffee",
                    "summary":"A primer on roasting coffee",
                    "created_at":"2021-09-03T10:06:08.582-07:00",
                    "duration":568,
                    "keywords":"",
                    "number":1,
                    "published_at":"2021-09-20T10:51:45.707-07:00",
                    "updated_at":"2021-09-20T10:51:45.707-07:00",
                    "season":200,
                    "type":"full",
                    "status":"published",
                    "author":"John Doe"
                 },
                 "relationships":{
                    "show":{
                       "data":{
                          "id":"24204",
                          "type":"show"
                       }
                    }
                 }
              },
              {
                 "id":"2",
                 "type":"episode",
                 "attributes":{
                    "title":"The Effects of Caffeine",
                    "summary":"A lightly scientific overview on how caffeine affects the brain",
                    "created_at":"2021-09-03T10:06:08.582-07:00",
                    "duration":568,
                    "keywords":"",
                    "number":2,
                    "published_at":"2021-09-20T10:51:45.707-07:00",
                    "updated_at":"2021-09-20T10:51:45.707-07:00",
                    "season":200,
                    "type":"full",
                    "status":"published",
                    "author":"John Doe"
                 },
                 "relationships":{
                    "show":{
                       "data":{
                          "id":"24204",
                          "type":"show"
                       }
                    }
                 }
              }
           ],
           "meta":{
              "currentPage":1,
              "totalPages":2,
              "totalCount":4
           }
        }
      R
    end
    let(:page2_response) do
      <<~R
        {
           "data":[
              {
                 "id":"3",
                 "type":"episode",
                 "attributes":{
                    "title":"I've actually decided I like tea better",
                    "summary":"A primer on good tea",
                    "created_at":"2021-09-03T10:06:08.582-07:00",
                    "duration":568,
                    "keywords":"",
                    "number":3,
                    "published_at":"2021-09-20T10:51:45.707-07:00",
                    "updated_at":"2021-09-20T10:51:45.707-07:00",
                    "season":200,
                    "type":"full",
                    "status":"published",
                    "author":"John Doe"
                 },
                 "relationships":{
                    "show":{
                       "data":{
                          "id":"24204",
                          "type":"show"
                       }
                    }
                 }
              },
              {
                 "id":"4",
                 "type":"episode",
                 "attributes":{
                    "title":"The Effects of Quitting Caffeine",
                    "summary":"I think I should really cut down",
                    "created_at":"2021-09-03T10:06:08.582-07:00",
                    "duration":568,
                    "keywords":"",
                    "number":4,
                    "published_at":"2021-09-20T10:51:45.707-07:00",
                    "updated_at":"2021-09-20T10:51:45.707-07:00",
                    "season":200,
                    "type":"full",
                    "status":"published",
                    "author":"John Doe"
                 },
                 "relationships":{
                    "show":{
                       "data":{
                          "id":"24204",
                          "type":"show"
                       }
                    }
                 }
              }
           ],
           "meta":{
              "currentPage":2,
              "totalPages":2,
              "totalCount":4
           }
        }
      R
    end
    let(:expected_items_count) { 4 }
    def stub_service_requests
      return [
        stub_request(:get, "https://api.transistor.fm/v1/episodes").
            with(body: "pagination%5Bpage%5D=1").
            to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://api.transistor.fm/v1/episodes").
            with(body: "pagination%5Bpage%5D=2").
            to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.transistor.fm/v1/episodes").
          to_return(status: 400, body: "try again later")
    end
  end

  it_behaves_like "a service implementation that can backfill incrementally", "transistor_episode_v1" do
    let(:page1_response) do
      <<~R
        {
           "data":[
              {
                 "id":"3",
                 "type":"episode",
                 "attributes":{
                    "title":"How To Roast Coffee",
                    "summary":"A primer on roasting coffee",
                    "created_at":"2021-04-03T10:06:08.582-07:00",
                    "duration":568,
                    "keywords":"",
                    "number":1,
                    "published_at":"2021-04-03T10:06:08.582-07:00",
                    "updated_at":"2021-04-03T10:06:08.582-07:00",
                    "season":200,
                    "type":"full",
                    "status":"published",
                    "author":"John Doe"
                 },
                 "relationships":{
                    "show":{
                       "data":{
                          "id":"24204",
                          "type":"show"
                       }
                    }
                 }
              },
              {
                 "id":"2",
                 "type":"episode",
                 "attributes":{
                    "title":"The Effects of Caffeine",
                    "summary":"A lightly scientific overview on how caffeine affects the brain",
                    "created_at":"2021-03-03T10:06:08.582-07:00",
                    "duration":568,
                    "keywords":"",
                    "number":2,
                    "published_at":"2021-03-03T10:06:08.582-07:00",
                    "updated_at":"2021-03-03T10:06:08.582-07:00",
                    "season":200,
                    "type":"full",
                    "status":"published",
                    "author":"John Doe"
                 },
                 "relationships":{
                    "show":{
                       "data":{
                          "id":"24204",
                          "type":"show"
                       }
                    }
                 }
              }
           ],
           "meta":{
              "currentPage":1,
              "totalPages":2,
              "totalCount":3
           }
        }
      R
    end
    let(:page2_response) do
      <<~R
        {
           "data":[
              {
                 "id":"1",
                 "type":"episode",
                 "attributes":{
                    "title":"I've actually decided I like tea better",
                    "summary":"A primer on good tea",
                    "created_at":"2021-02-03T10:06:08.582-07:00",
                    "duration":568,
                    "keywords":"",
                    "number":3,
                    "published_at":"2021-02-03T10:06:08.582-07:00",
                    "updated_at":"2021-02-03T10:06:08.582-07:00",
                    "season":200,
                    "type":"full",
                    "status":"published",
                    "author":"John Doe"
                 },
                 "relationships":{
                    "show":{
                       "data":{
                          "id":"24204",
                          "type":"show"
                       }
                    }
                 }
              }
           ],
           "meta":{
              "currentPage":2,
              "totalPages":2,
              "totalCount":3
           }
        }
      R
    end
    let(:last_backfilled) { "2021-03-31T10:06:08.582-07:00" }
    let(:expected_new_items_count) { 2 }
    let(:expected_old_items_count) { 1 }
    def stub_service_requests_new_records
      return [
        stub_request(:get, "https://api.transistor.fm/v1/episodes").
            with(body: "pagination%5Bpage%5D=1").
            to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_service_requests_old_records
      return [
        stub_request(:get, "https://api.transistor.fm/v1/episodes").
            with(body: "pagination%5Bpage%5D=2").
            to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"}),
      ]
    end
  end

  describe "webhook validation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "transistor_episode_v1") }
    let(:svc) { Webhookdb::Services.service_instance(sint) }

    it "returns a 202 no matter what" do
      req = fake_request
      status, _headers, _body = svc.webhook_response(req)
      expect(status).to eq(202)
    end
  end

  describe "state machine calculation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "transistor_episode_v1") }
    let(:svc) { Webhookdb::Services.service_instance(sint) }

    describe "calculate_create_state_machine" do
      it "returns a backfill step" do
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          output: match("does not support Episode webhooks"),
        )
      end
    end
    describe "calculate_backfill_state_machine" do
      let(:success_body) do
        <<~R
          {
            "data": [],
            "meta": {}
          }
        R
      end
      def stub_service_request
        return stub_request(:get, "https://api.transistor.fm/v1/episodes").
            with(headers: {"X-Api-Key" => "bfkey"}).
            to_return(status: 200, body: success_body, headers: {})
      end
      it "it asks for backfill key" do
        sm = sint.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: start_with("Paste or type"),
          prompt_is_secret: true,
          post_to_url: "/v1/service_integrations/#{sint.opaque_id}/transition/backfill_key",
          complete: false,
          output: match("does not support Episode webhooks"),
        )
      end
      it "returns backfill in progress message" do
        sint.backfill_key = "bfkey"
        res = stub_service_request
        sm = sint.calculate_backfill_state_machine
        expect(res).to have_been_made
        expect(sm).to have_attributes(
          needs_input: false,
          prompt: false,
          prompt_is_secret: false,
          post_to_url: "",
          complete: true,
          output: match("Great! We are going to start backfilling your Transistor Episodes."),
        )
      end
    end
  end

  it_behaves_like "a service implementation that uses enrichments", "transistor_episode_v1" do
    let(:enrichment_tables) { svc.enrichment_tables }
    let(:body) do
      JSON.parse(<<~J)
        {"data": {
              "id":"655205",
              "type":"episode",
              "attributes":{
                 "title":"THE SHOW",
                 "number":1,
                 "season":1,
                 "status":"published",
                 "published_at":"2021-09-20T10:51:45.707-07:00",
                 "duration":236,
                 "explicit":false,
                 "keywords":"",
                 "alternate_url":"",
                 "media_url":"https://media.transistor.fm/70562b4e/83984906.mp3",
                 "image_url":null,
                 "author":"",
                 "summary":"readgssfdctwadg",
                 "description":"",
                 "created_at":"2021-09-03T10:06:08.582-07:00",
                 "updated_at":"2021-09-20T10:51:45.708-07:00",
                 "formatted_published_at":"September 20, 2021",
                 "duration_in_mmss":"03:56",
                 "share_url":"https://share.transistor.fm/s/70562b4e",
                 "formatted_summary":"readgssfdctwadg",
                 "audio_processing":false,
                 "type":"full",
                 "email_notifications":null
              },
              "relationships":{
                 "show":{
                    "data":{
                       "id":"24204",
                       "type":"show"
                    }
                 }
              }
        }}
      J
    end
    let(:analytics_body) do
      <<~R
        {
           "data":{
              "id":"655205",
              "type":"episode_analytics",
              "attributes":{
                 "downloads":[
                    {
                       "date":"03-09-2021",
                       "downloads":0
                    },
                    {
                       "date":"04-09-2021",
                       "downloads":0
                    }
                 ],
                 "start_date":"03-09-2021",
                 "end_date":"16-09-2021"
              },
              "relationships":{
                 "episode":{
                    "data":{
                       "id":"1",
                       "type":"episode"
                    }
                 }
              }
           },
           "included":[
              {
                 "id":"655205",
                 "type":"episode",
                 "attributes":{
                    "title":"THE SHOW"
                 },
                 "relationships":{
                 }
              }
           ]
        }
      R
    end

    def stub_service_request
      return stub_request(:get, "https://api.transistor.fm/v1/analytics/episodes/655205").
          to_return(status: 200, headers: {"Content-Type" => "application/json"}, body: analytics_body)
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.transistor.fm/v1/analytics/episodes/655205").
          to_return(status: 503, body: "whoo")
    end

    def assert_is_enriched(_row)
      # we are not enriching data within the table, so this can just return true
      return true
    end

    def assert_enrichment_after_insert(db)
      enrichment_table_sym = enrichment_tables[0].to_sym
      expect(db[enrichment_table_sym].all).to have_length(2)

      entry = db[enrichment_table_sym].first
      expect(entry).to include(episode_id: "655205", downloads: 0)
    end
  end

  describe "_fetch_enrichment" do
    before(:each) do
      sint.organization.prepare_database_connections
      svc.create_table
    end

    after(:each) do
      sint.organization.remove_related_database
    end

    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "transistor_episode_v1") }
    let(:svc) { Webhookdb::Services.service_instance(sint) }
    let(:enrichment_tables) { svc.enrichment_tables }
    let(:body) do
      JSON.parse(<<~J)
        {"data": {
              "id":"655205",
              "type":"episode",
              "attributes":{
                 "title":"THE SHOW",
                 "number":1,
                 "season":1,
                 "status":"published",
                 "published_at":"2021-09-20T10:51:45.707-07:00",
                 "duration":236,
                 "explicit":false,
                 "keywords":"",
                 "alternate_url":"",
                 "media_url":"https://media.transistor.fm/70562b4e/83984906.mp3",
                 "image_url":null,
                 "author":"",
                 "summary":"readgssfdctwadg",
                 "description":"",
                 "created_at":"2021-09-03T10:06:08.582-07:00",
                 "updated_at":"2021-09-20T10:51:45.708-07:00",
                 "formatted_published_at":"September 20, 2021",
                 "duration_in_mmss":"03:56",
                 "share_url":"https://share.transistor.fm/s/70562b4e",
                 "formatted_summary":"readgssfdctwadg",
                 "audio_processing":false,
                 "type":"full",
                 "email_notifications":null
              },
              "relationships":{
                 "show":{
                    "data":{
                       "id":"24204",
                       "type":"show"
                    }
                 }
              }
        }}
      J
    end

    it "makes the request" do
      req = stub_request(:get, "https://api.transistor.fm/v1/analytics/episodes/655205").
        to_return(
          status: 200,
          headers: {"Content-Type" => "application/json"},
          body: {
            data: {
              id: "1",
              type: "episode_analytics",
              attributes: {},
            },
          }.to_json,
        )
      expect(svc._fetch_enrichment(body)).to include("data" => include("id" => "1"))
      expect(req).to have_been_made
    end

    it "adjusts 'start_date' parameter in request if there are entries already present in enrichment table" do
      stats_table_name = enrichment_tables[0].to_sym
      svc.admin_dataset(&:db)[stats_table_name].insert(episode_id: "655205", date: Date.new(2021, 10, 1))
      req = stub_request(:get, "https://api.transistor.fm/v1/analytics/episodes/655205").
        with(
          body: /start_date=29-09-2021&end_date=/,
          headers: {
            "Accept" => "*/*",
            "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
            "User-Agent" => "Ruby",
            "X-Api-Key" => "",
          },
        ).
        to_return(
          status: 200,
          headers: {"Content-Type" => "application/json"},
          body: {
            data: {
              id: "1",
              type: "episode_analytics",
              attributes: {},
            },
          }.to_json,
        )
      svc._fetch_enrichment(body)
      expect(req).to have_been_made
    end

    it "sleeps to avoid rate limiting" do
      Webhookdb::Transistor.sleep_seconds = 1.2
      expect(Kernel).to receive(:sleep).with(1.2)
      svc._fetch_enrichment(body)
    end
    it "errors if the API call errors" do
      req = stub_request(:get, "https://api.transistor.fm/v1/analytics/episodes/655205").
        to_return(status: 400, headers: {"Content-Type" => "application/json"}, body: "something went wrong")
      expect { svc._fetch_enrichment(body) }.to raise_error(Webhookdb::Http::Error)
      expect(req).to have_been_made
    end
  end

  describe "specialized enrichment behavior" do
    before(:each) do
      sint.organization.prepare_database_connections
    end

    after(:each) do
      sint.organization.remove_related_database
    end

    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "transistor_episode_v1") }
    let(:svc) { Webhookdb::Services.service_instance(sint) }
    let(:enrichment_tables) { svc.enrichment_tables }
    let(:body) do
      JSON.parse(<<~J)
        {"data": {
              "id":"655205",
              "type":"episode",
              "attributes":{
                 "title":"THE SHOW",
                 "number":1,
                 "season":1,
                 "status":"published",
                 "published_at":"2021-09-20T10:51:45.707-07:00",
                 "duration":236,
                 "explicit":false,
                 "keywords":"",
                 "alternate_url":"",
                 "media_url":"https://media.transistor.fm/70562b4e/83984906.mp3",
                 "image_url":null,
                 "author":"",
                 "summary":"readgssfdctwadg",
                 "description":"",
                 "created_at":"2021-04-03T10:06:08.582-07:00",
                 "updated_at":"2021-09-20T10:51:45.708-07:00",
                 "formatted_published_at":"September 20, 2021",
                 "duration_in_mmss":"03:56",
                 "share_url":"https://share.transistor.fm/s/70562b4e",
                 "formatted_summary":"readgssfdctwadg",
                 "audio_processing":false,
                 "type":"full",
                 "email_notifications":null
              },
              "relationships":{
                 "show":{
                    "data":{
                       "id":"24204",
                       "type":"show"
                    }
                 }
              }
        }}
      J
    end

    let(:old_analytics_body) do
      <<~R
        {
           "data":{
              "id":"655205",
              "type":"episode_analytics",
              "attributes":{
                 "downloads":[
                    {
                       "date":"03-09-2021",
                       "downloads":1
                    }
                 ],
                 "start_date":"03-09-2021",
                 "end_date":"16-09-2021"
              },
              "relationships":{
                 "episode":{
                    "data":{
                       "id":"1",
                       "type":"episode"
                    }
                 }
              }
           },
           "included":[
              {
                 "id":"655205",
                 "type":"episode",
                 "attributes":{
                    "title":"THE SHOW"
                 },
                 "relationships":{
                 }
              }
           ]
        }
      R
    end

    let(:new_analytics_body) do
      <<~R
        {
           "data":{
              "id":"655205",
              "type":"episode_analytics",
              "attributes":{
                 "downloads":[
                    {
                       "date":"03-09-2021",
                       "downloads":2
                    },
                    {
                       "date":"04-09-2021",
                       "downloads":2
                    }
                 ],
                 "start_date":"03-09-2021",
                 "end_date":"16-09-2021"
              },
              "relationships":{
                 "episode":{
                    "data":{
                       "id":"1",
                       "type":"episode"
                    }
                 }
              }
           },
           "included":[
              {
                 "id":"655205",
                 "type":"episode",
                 "attributes":{
                    "title":"THE SHOW"
                 },
                 "relationships":{
                 }
              }
           ]
        }
      R
    end

    it "will upsert based on episode and date_id" do
      svc.create_table
      first_req = stub_request(:get, "https://api.transistor.fm/v1/analytics/episodes/655205").
        with(
          body: /start_date=03-04-2021&end_date=/,
        ).
        to_return(status: 200, headers: {"Content-Type" => "application/json"}, body: old_analytics_body)
      second_req = stub_request(:get, "https://api.transistor.fm/v1/analytics/episodes/655205").
        with(
          body: /start_date=01-09-2021&end_date=/,
        ).
        to_return(status: 200, headers: {"Content-Type" => "application/json"}, body: new_analytics_body)

      svc.upsert_webhook(body:)
      expect(first_req).to have_been_made

      svc.upsert_webhook(body:)
      expect(second_req).to have_been_made

      enrichment_table_sym = enrichment_tables[0].to_sym
      db = svc.readonly_dataset(&:db)
      expect(db[enrichment_table_sym].all).to have_length(2)
      expect(db[enrichment_table_sym].all).to contain_exactly(
        include(episode_id: "655205", date: Date.new(2021, 9, 3),
                downloads: 2,), include(episode_id: "655205", date: Date.new(2021, 9, 4), downloads: 2),
      )
    end
  end
end
