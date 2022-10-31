# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::TransistorShowV1, :db do
  it_behaves_like "a replicator", "transistor_show_v1" do
    let(:body) do
      JSON.parse(<<~J)
        {
          "data": {
            "id": "1",
            "type": "show",
            "attributes": {
              "author": null,
              "category": "Arts :: Food",
              "copyright": null,
              "created_at": "2020-02-01 00:00:00 UTC",
              "description": "A podcast covering all things coffee and caffeine",
              "explicit": false,
              "image_url": null,
              "keywords": "coffee,caffeine,beans",
              "language": "en",
              "multiple_seasons": false,
              "owner_email": null,
              "playlist_limit": 25,
              "private": false,
              "secondary_category": "Arts",
              "show_type": "episodic",
              "slug": "the-caffeine-show",
              "time_zone": null,
              "title": "The Caffeine Show",
              "updated_at": "2020-06-01 00:00:00 UTC",
              "website": null,
              "password_protected_feed": false,
              "breaker": null,
              "castbox": null,
              "castro": null,
              "feed_url": "https://feeds.transistor.fm/the-caffeine-show",
              "google_podcasts": null,
              "iHeartRadio": null,
              "overcast": null,
              "pandora": null,
              "pocket_casts": null,
              "radioPublic": null,
              "soundcloud": null,
              "stitcher": null,
              "tuneIn": null,
              "spotify": null,
              "apple_podcasts": null,
              "deezer": null,
              "amazon_music": null,
              "player_FM": null,
              "podcast_addict": null,
              "email_notifications": false
            },
            "relationships": {
              "episodes": {
                "data": []
              }
            }
          }
        }
      J
    end
    let(:expected_data) { body["data"] }
  end

  it_behaves_like "a replicator that prevents overwriting new data with old", "transistor_show_v1" do
    let(:old_body) do
      JSON.parse(<<~J)
        {
          "data": {
            "id": "1",
            "type": "show",
            "attributes": {
              "author": null,
              "category": "Arts :: Food",
              "copyright": null,
              "created_at": "2020-02-01 00:00:00 UTC",
              "description": "A podcast covering all things coffee and caffeine",
              "explicit": false,
              "image_url": null,
              "keywords": "coffee,caffeine,beans",
              "language": "en",
              "multiple_seasons": false,
              "owner_email": null,
              "playlist_limit": 25,
              "private": false,
              "secondary_category": "Arts",
              "show_type": "episodic",
              "slug": "the-caffeine-show",
              "time_zone": null,
              "title": "The Caffeine Show",
              "updated_at": "2020-06-01 00:00:00 UTC",
              "website": null,
              "password_protected_feed": false,
              "breaker": null,
              "castbox": null,
              "castro": null,
              "feed_url": "https://feeds.transistor.fm/the-caffeine-show",
              "google_podcasts": null,
              "iHeartRadio": null,
              "overcast": null,
              "pandora": null,
              "pocket_casts": null,
              "radioPublic": null,
              "soundcloud": null,
              "stitcher": null,
              "tuneIn": null,
              "spotify": null,
              "apple_podcasts": null,
              "deezer": null,
              "amazon_music": null,
              "player_FM": null,
              "podcast_addict": null,
              "email_notifications": false
            },
            "relationships": {
              "episodes": {
                "data": []
              }
            }
          }
        }
      J
    end
    let(:new_body) do
      JSON.parse(<<~J)
        {
          "data": {
            "id": "1",
            "type": "show",
            "attributes": {
              "author": null,
              "category": "Arts :: Food",
              "copyright": null,
              "created_at": "2020-02-01 00:00:00 UTC",
              "description": "A podcast covering all things coffee and caffeine",
              "explicit": false,
              "image_url": null,
              "keywords": "coffee,caffeine,beans",
              "language": "en",
              "multiple_seasons": false,
              "owner_email": null,
              "playlist_limit": 25,
              "private": false,
              "secondary_category": "Arts",
              "show_type": "episodic",
              "slug": "the-caffeine-show",
              "time_zone": null,
              "title": "The Caffeine Show",
              "updated_at": "2020-07-01 00:00:00 UTC",
              "website": null,
              "password_protected_feed": false,
              "breaker": null,
              "castbox": null,
              "castro": null,
              "feed_url": "https://feeds.transistor.fm/the-caffeine-show",
              "google_podcasts": null,
              "iHeartRadio": null,
              "overcast": null,
              "pandora": null,
              "pocket_casts": null,
              "radioPublic": null,
              "soundcloud": null,
              "stitcher": null,
              "tuneIn": null,
              "spotify": null,
              "apple_podcasts": null,
              "deezer": null,
              "amazon_music": null,
              "player_FM": null,
              "podcast_addict": null,
              "email_notifications": false
            },
            "relationships": {
              "episodes": {
                "data": []
              }
            }
          }
        }
      J
    end
    let(:expected_old_data) { old_body["data"] }
    let(:expected_new_data) { new_body["data"] }
  end

  it_behaves_like "a replicator that verifies backfill secrets" do
    let(:correct_creds_sint) do
      Webhookdb::Fixtures.service_integration.create(
        service_name: "transistor_show_v1",
        backfill_key: "bfkey",
      )
    end
    let(:incorrect_creds_sint) do
      Webhookdb::Fixtures.service_integration.create(
        service_name: "transistor_show_v1",
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
      return stub_request(:get, "https://api.transistor.fm/v1/shows").
          with(headers: {"X-Api-Key" => "bfkey"}).
          to_return(status: 200, body: success_body, headers: {})
    end

    def stub_service_request_error
      stub_request(:get, "https://api.transistor.fm/v1/shows").
        with(headers: {"X-Api-Key" => "bfkey_wrong"}).
        to_return(status: 401, body: "", headers: {})
    end
  end

  it_behaves_like "a replicator that can backfill", "transistor_show_v1" do
    let(:page1_response) do
      <<~R
        {
           "data":[
              {
                 "id":"1",
                 "type":"show",
                 "attributes":{
                    "title":"The Caffeine Show",
                    "description":"A podcast covering all things coffee and caffeine",
                    "website":"example.com",
                    "author":"John Doe",
                    "created_at":"2021-09-20T10:06:08.582-07:00",
                    "updated_at":"2021-09-20T10:51:45.708-07:00"
                 },
                 "relationships":{}
              }
           ],
           "meta":{
              "currentPage":1,
              "totalPages":2,
              "totalCount":2
           }
        }
      R
    end
    let(:page2_response) do
      <<~R
        {
           "data":[
              {
                 "id":"2",
                 "type":"show",
                 "attributes":{
                    "title":"The TV Show",
                    "description":"A podcast covering all things TV",
                    "website":"example.com",
                    "author":"John Doe",
                    "created_at":"2021-09-20T10:06:08.582-07:00",
                    "updated_at":"2021-09-20T10:51:45.708-07:00"
                 },
                 "relationships":{}
              }
           ],
           "meta":{
              "currentPage":2,
              "totalPages":2,
              "totalCount":2
           }
        }
      R
    end
    let(:page3_response) do
      <<~R
        {
           "data":[
              {
                 "id":"3",
                 "type":"show",
                 "attributes":{
                    "title":"The Secret Caffeine Show",
                    "description":"A podcast about coffee and caffeine secrets",
                    "website":"example.com",
                    "author":"John Doe",
                    "created_at":"2021-09-20T10:06:08.582-07:00",
                    "updated_at":"2021-09-20T10:51:45.708-07:00"
                 },
                 "relationships":{}
              }
           ],
           "meta":{
              "currentPage":1,
              "totalPages":2,
              "totalCount":2
           }
        }
      R
    end
    let(:page4_response) do
      <<~R
        {
           "data":[
              {
                 "id":"4",
                 "type":"show",
                 "attributes":{
                    "title":"The Secret TV Show",
                    "description":"A podcast about TV secrets",
                    "website":"example.com",
                    "author":"John Doe",
                    "created_at":"2021-09-20T10:06:08.582-07:00",
                    "updated_at":"2021-09-20T10:51:45.708-07:00"
                 },
                 "relationships":{}
              }
           ],
           "meta":{
              "currentPage":2,
              "totalPages":2,
              "totalCount":2
           }
        }
      R
    end
    let(:expected_items_count) { 4 }
    def stub_service_requests
      return [
        stub_request(:get, "https://api.transistor.fm/v1/shows").
            with(body: "pagination%5Bpage%5D=1&private=false").
            to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://api.transistor.fm/v1/shows").
            with(body: "pagination%5Bpage%5D=2&private=false").
            to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://api.transistor.fm/v1/shows").
            with(body: "pagination%5Bpage%5D=1&private=true").
            to_return(status: 200, body: page3_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://api.transistor.fm/v1/shows").
            with(body: "pagination%5Bpage%5D=2&private=true").
            to_return(status: 200, body: page4_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_empty_requests
      body = {data: [], meta: {totalPages: 1, currentPage: 1}}.to_json
      return [
        stub_request(:get, "https://api.transistor.fm/v1/shows").
            with(body: "pagination%5Bpage%5D=1&private=false").
            to_return(status: 200, body:, headers: json_headers),
        stub_request(:get, "https://api.transistor.fm/v1/shows").
            with(body: "pagination%5Bpage%5D=1&private=true").
            to_return(status: 200, body:, headers: json_headers),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.transistor.fm/v1/shows").
          to_return(status: 400, body: "try again later")
    end
  end

  describe "webhook validation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "transistor_show_v1") }
    let(:svc) { Webhookdb::Replicator.create(sint) }

    it "returns a 202 no matter what" do
      req = fake_request
      status, _headers, _body = svc.webhook_response(req).to_rack
      expect(status).to eq(202)
    end
  end

  describe "state machine calculation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "transistor_show_v1") }
    let(:svc) { Webhookdb::Replicator.create(sint) }

    describe "calculate_create_state_machine" do
      it "returns a backfill step" do
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          output: match("Transistor does not support Transistor Show webhooks"),
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
        return stub_request(:get, "https://api.transistor.fm/v1/shows").
            with(headers: {"X-Api-Key" => "bfkey"}).
            to_return(status: 200, body: success_body, headers: {})
      end
      it "asks for backfill key" do
        sm = sint.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: start_with("Paste or type"),
          prompt_is_secret: true,
          post_to_url: end_with("/service_integrations/#{sint.opaque_id}/transition/backfill_key"),
          complete: false,
          output: match("Transistor does not support"),
        )
      end

      it "returns backfill in progress message" do
        sint.backfill_key = "bfkey"
        res = stub_service_request
        sm = sint.calculate_backfill_state_machine
        expect(res).to have_been_made
        expect(sm).to have_attributes(
          needs_input: false,
          prompt: "",
          prompt_is_secret: false,
          post_to_url: "",
          complete: true,
          output: match("We are going to start backfilling your Transistor Shows"),
        )
      end
    end
  end
end
