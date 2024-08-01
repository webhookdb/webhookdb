# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::TransistorEpisodeV1, :db do
  it_behaves_like "a replicator" do
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
    let(:expected_data) { body["data"] }
  end

  it_behaves_like "a replicator that prevents overwriting new data with old" do
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
    let(:expected_old_data) { old_body["data"] }
    let(:expected_new_data) { new_body["data"] }
  end

  it_behaves_like "a replicator that verifies backfill secrets" do
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

  it_behaves_like "a replicator that can backfill" do
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
            with(body: "pagination%5Bpage%5D=1&pagination%5Bper%5D=500").
            to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://api.transistor.fm/v1/episodes").
            with(body: "pagination%5Bpage%5D=2&pagination%5Bper%5D=500").
            to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_empty_requests
      body = {data: [], meta: {currentPage: 1, totalPages: 1}}.to_json
      return [
        stub_request(:get, "https://api.transistor.fm/v1/episodes").
            to_return(status: 200, body:, headers: json_headers),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.transistor.fm/v1/episodes").
          to_return(status: 400, body: "try again later")
    end
  end

  it_behaves_like "a replicator that can backfill incrementally" do
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
    def stub_service_requests(partial:)
      new_reqs = [
        stub_request(:get, "https://api.transistor.fm/v1/episodes").
          with(body: "pagination%5Bpage%5D=1&pagination%5Bper%5D=500").
          to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}),
      ]
      return new_reqs if partial
      old_reqs = [
        stub_request(:get, "https://api.transistor.fm/v1/episodes").
          with(body: "pagination%5Bpage%5D=2&pagination%5Bper%5D=500").
          to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"}),
      ]
      return old_reqs + new_reqs
    end
  end

  it_behaves_like "a replicator that uses enrichments", stores_enrichment_column: false do
    let(:body) do
      JSON.parse(<<~JSON)
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
                 "transcript_url":"https://share.transistor.fm/s/1dde3f66/transcript",
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
      JSON
    end

    let(:transcript) { "me: hi there!\n\nyou: hello!\n" }

    def stub_service_request
      return stub_request(:get, "https://share.transistor.fm/s/1dde3f66/transcript.txt").
          to_return(status: 200, body: transcript)
    end

    def stub_service_request_error(status: 500)
      return stub_request(:get, "https://share.transistor.fm/s/1dde3f66/transcript.txt").to_return(status:)
    end

    def assert_is_enriched(row)
      expect(row).to include(transcript_text: transcript)
    end

    it "can handle transcript urls that already have a .txt extension" do
      body["data"]["attributes"]["transcript_url"] += ".txt"
      req = stub_service_request
      upsert_webhook(svc, body:)
      expect(req).to have_been_made
      row = svc.readonly_dataset(&:first)
      assert_is_enriched(row)
    end

    it "noops if there is no transcript url" do
      body["data"]["attributes"]["transcript_url"] = nil
      upsert_webhook(svc, body:)
      row = svc.readonly_dataset(&:first)
      expect(row).to include(transcript_text: nil)
    end

    it "ignores 404s on the transcript" do
      body["data"]["attributes"]["transcript_url"] += ".txt"
      req = stub_service_request_error(status: 404)
      upsert_webhook(svc, body:)
      expect(req).to have_been_made
      row = svc.readonly_dataset(&:first)
      expect(row).to include(transcript_text: nil)
    end
  end

  describe "webhook validation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "transistor_episode_v1") }
    let(:svc) { Webhookdb::Replicator.create(sint) }

    it "returns a 202 no matter what" do
      req = fake_request
      status, _headers, _body = svc.webhook_response(req).to_rack
      expect(status).to eq(202)
    end
  end

  describe "state machine calculation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "transistor_episode_v1") }
    let(:svc) { Webhookdb::Replicator.create(sint) }

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
      it "asks for backfill key" do
        sm = sint.replicator.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: start_with("Paste or type"),
          prompt_is_secret: true,
          post_to_url: end_with("/service_integrations/#{sint.opaque_id}/transition/backfill_key"),
          complete: false,
          output: match("does not support Transistor Episode webhooks"),
        )
      end

      it "returns backfill in progress message" do
        sint.backfill_key = "bfkey"
        res = stub_service_request
        sm = sint.replicator.calculate_backfill_state_machine
        expect(res).to have_been_made
        expect(sm).to have_attributes(
          needs_input: false,
          prompt: "",
          prompt_is_secret: false,
          post_to_url: "",
          complete: true,
          output: match("Great! We are going to start replicating your Transistor Episodes."),
        )
      end
    end
  end

  describe "logical summary and description" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "transistor_episode_v1") }
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
    let(:svc) { Webhookdb::Replicator.create(sint) }

    Webhookdb::SpecHelpers::Whdb.setup_upsert_webhook_example(self)
    before(:each) do
      sint.organization.prepare_database_connections
      svc.create_table
    end

    after(:each) do
      sint.organization.remove_related_database
    end

    it "uses description and formatted_summary verbatim for the 'legacy' format" do
      body["data"]["attributes"]["description"] = "<div>param 1</div><div>para 2</div>"
      body["data"]["attributes"]["summary"] = "Make it short."
      body["data"]["attributes"]["formatted_summary"] = "Make it short."

      upsert_webhook(svc, body:)
      svc.readonly_dataset do |ds|
        expect(ds.first).to include(
          logical_summary: "Make it short.",
          logical_description: "<div>param 1</div><div>para 2</div>",
          api_format: 1,
        )
      end
    end

    it "extracts the first description line (using br) for the combined format" do
      body["data"]["attributes"]["description"] =
        " <div>Make it short. <br><br><strong>Links:</strong></div><ul><li>hi</li></ul>"
      body["data"]["attributes"]["summary"] = nil
      body["data"]["attributes"]["formatted_summary"] = "Make it short. Links: hi"

      upsert_webhook(svc, body:)
      svc.readonly_dataset do |ds|
        expect(ds.first).to include(
          logical_summary: "Make it short.",
          logical_description: "<div><strong>Links:</strong></div><ul><li>hi</li></ul>",
          api_format: 2,
        )
      end
    end

    it "extracts the first description line (using nested div) for the combined format" do
      body["data"]["attributes"]["description"] =
        " <div>Make it short. <div><strong>Links:</strong></div><ul><li>hi</li></ul></div>"
      body["data"]["attributes"]["summary"] = nil
      body["data"]["attributes"]["formatted_summary"] = "Make it short. Links: hi"

      upsert_webhook(svc, body:)
      svc.readonly_dataset do |ds|
        expect(ds.first).to include(
          logical_summary: "Make it short.",
          logical_description: "<div><div><strong>Links:</strong></div><ul><li>hi</li></ul></div>",
          api_format: 2,
        )
      end
    end

    it "is smart about block elements in the description line" do
      body["data"]["attributes"]["description"] =
        "<p>Super Show <em>Extras</em> edition.</p><p>It's a good show.</p>"
      body["data"]["attributes"]["summary"] = nil
      body["data"]["attributes"]["formatted_summary"] = "Super Show Extras edition.Its a good show."

      upsert_webhook(svc, body:)
      svc.readonly_dataset do |ds|
        expect(ds.first).to include(
          logical_summary: "Super Show <em>Extras</em> edition.",
          logical_description: "<p>It's a good show.</p>",
          api_format: 2,
        )
      end
    end

    it "uses the description as the summary if there is just one line" do
      body["data"]["attributes"]["description"] = " <div>Make it short. </div>"
      body["data"]["attributes"]["summary"] = nil
      body["data"]["attributes"]["formatted_summary"] = "Make it short."

      upsert_webhook(svc, body:)
      svc.readonly_dataset do |ds|
        expect(ds.first).to include(
          logical_summary: "Make it short.",
          logical_description: nil,
          api_format: 2,
        )
      end
    end
  end
end
