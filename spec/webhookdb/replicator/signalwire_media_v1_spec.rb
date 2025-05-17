# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::SignalwireMediaV1, :db do
  def message_with_media(num, sid: "SMabcxyz", account_sid: "AC123", **kw)
    d = {
      account_sid:,
      api_version: "2010-04-01",
      body: "testing",
      date_created: "Fri, 24 May 2019 17:44:46 +0000",
      date_sent: "Fri, 24 May 2019 17:44:50 +0000",
      date_updated: "Fri, 24 May 2019 17:44:50 +0000",
      direction: "outbound-api",
      error_code: nil,
      error_message: nil,
      from: "+15559235161",
      messaging_service_sid: nil,
      num_media: num,
      num_segments: 1,
      price: -0.00750,
      price_unit: "USD",
      sid:,
      status: "sent",
      subresource_uris: {
        media: "/api/laml/2010-04-01/Accounts/#{account_sid}/Messages/#{sid}/Media.json",
      },
      to: "+15552008801",
      uri: "/api/laml/2010-04-01/Accounts/#{account_sid}/Messages/#{sid}.json",
    }
    d.merge!(kw)
    return d.as_json
  end

  it_behaves_like "a replicator" do
    let(:body) do
      JSON.parse(<<~JSON)
        {
          "sid": "4f95ee4d-ad83-477f-9500-10cb321f19c6",
          "date_created": "Sat, 17 May 2025 05:07:58 +0000",
          "date_updated": "Sat, 17 May 2025 05:07:58 +0000",
          "account_sid": "AC123",
          "parent_sid": "SMabcxyz",
          "content_type": "text/plain",
          "uri": "/api/laml/2010-04-01/Accounts/AC123/Messages/SMabcxyz/Media/4f95ee4d-ad83-477f-9500-10cb321f19c6.json"
        }
      JSON
    end
  end

  it_behaves_like "a replicator that prevents overwriting new data with old" do
    let(:old_body) do
      JSON.parse(<<~JSON)
        {
          "sid": "4f95ee4d-ad83-477f-9500-10cb321f19c6",
          "date_created": "Sat, 17 May 2025 05:07:58 +0000",
          "date_updated": "Sat, 17 May 2025 05:07:58 +0000",
          "account_sid": "AC123",
          "parent_sid": "SMabcxyz",
          "content_type": "text/plain",
          "uri": "/api/laml/2010-04-01/Accounts/AC123/Messages/SMabcxyz/Media/4f95ee4d-ad83-477f-9500-10cb321f19c6.json"
        }
      JSON
    end
    let(:new_body) do
      JSON.parse(<<~JSON)
        {
          "sid": "4f95ee4d-ad83-477f-9500-10cb321f19c6",
          "date_created": "Sat, 17 May 2025 05:07:58 +0000",
          "date_updated": "Sat, 18 May 2025 05:07:58 +0000",
          "account_sid": "AC123",
          "parent_sid": "SMabcxyz",
          "content_type": "text/plain",
          "uri": "/api/laml/2010-04-01/Accounts/AC123/Messages/SMabcxyz/Media/4f95ee4d-ad83-477f-9500-10cb321f19c6.json",
          "some_other_field": "hi"
        }
      JSON
    end
  end

  it_behaves_like "a replicator that can backfill" do
    let(:today) { Time.parse("2020-11-22T18:00:00Z") }
    let(:page1_response) do
      <<~JSON
        {
          "uri": "/api/laml/2010-04-01/Accounts/AC123/Messages/SMabcxyz/Media?Page=0&PageSize=2",
          "first_page_uri": "/api/laml/2010-04-01/Accounts/AC123/Messages/SMabcxyz/Media?Page=0&PageSize=2",
          "next_page_uri": "/api/laml/2010-04-01/Accounts/AC123/Messages/SMabcxyz/Media?Page=1&PageSize=2",
          "previous_page_uri": null,
          "page": 0,
          "page_size": 2,
          "media_list": [
            {
              "sid": "4f95ee4d-ad83-477f-9500-10cb321f19c6",
              "date_created": "Sat, 17 May 2025 05:07:58 +0000",
              "date_updated": "Sat, 17 May 2025 05:07:58 +0000",
              "account_sid": "AC123",
              "parent_sid": "SMabcxyz",
              "content_type": "text/plain",
              "uri": "/api/laml/2010-04-01/Accounts/AC123/Messages/SMabcxyz/Media/4f95ee4d-ad83-477f-9500-10cb321f19c6.json"
            },
            {
              "sid": "68eaa1df-3e4c-4669-a34c-246b0bf9f3f0",
              "date_created": "Sat, 17 May 2025 05:07:57 +0000",
              "date_updated": "Sat, 17 May 2025 05:07:58 +0000",
              "account_sid": "AC123",
              "parent_sid": "SMabcxyz",
              "content_type": "image/jpeg",
              "uri": "/api/laml/2010-04-01/Accounts/AC123/Messages/SMabcxyz/Media/68eaa1df-3e4c-4669-a34c-246b0bf9f3f0.json"
            }
          ]
        }
      JSON
    end
    let(:page2_response) do
      <<~JSON
        {
          "uri": "/api/laml/2010-04-01/Accounts/AC123/Messages/SMabcxyz/Media?Page=0&PageSize=2",
          "first_page_uri": "/api/laml/2010-04-01/Accounts/AC123/Messages/SMabcxyz/Media?Page=0&PageSize=2",
          "next_page_uri": "/api/laml/2010-04-01/Accounts/AC123/Messages/SMabcxyz/Media?Page=2&PageSize=2",
          "previous_page_uri": "/api/laml/2010-04-01/Accounts/AC123/Messages/SMabcxyz/Media?Page=1&PageSize=2",
          "page": 0,
          "page_size": 2,
          "media_list": [
            {
              "sid": "f192e224-e810-4a7b-ab57-0a7942415631",
              "date_created": "Sat, 17 May 2025 05:07:56 +0000",
              "date_updated": "Sat, 17 May 2025 05:07:57 +0000",
              "account_sid": "AC123",
              "parent_sid": "SMabcxyz",
              "content_type": "image/jpeg",
              "uri": "/api/laml/2010-04-01/Accounts/AC123/Messages/SMabcxyz/Media/f192e224-e810-4a7b-ab57-0a7942415631.json"
            }
          ]
        }
      JSON
    end
    let(:page3_response) do
      <<~JSON
        {
          "uri": "/api/laml/2010-04-01/Accounts/AC123/Messages/SMabcxyz/Media?Page=0&PageSize=2",
          "first_page_uri": "/api/laml/2010-04-01/Accounts/AC123/Messages/SMabcxyz/Media?Page=0&PageSize=2",
          "next_page_uri": null,
          "previous_page_uri": "/api/laml/2010-04-01/Accounts/AC123/Messages/SMabcxyz/Media?Page=1&PageSize=2",
          "page": 0,
          "page_size": 2,
          "media_list": []
        }
      JSON
    end
    let(:expected_items_count) { 3 }

    def stub_service_requests
      return [
        stub_request(:get, "https://whdbtestfake.signalwire.com/api/laml/2010-04-01/Accounts/AC123/Messages/SMabcxyz/Media").
            with(headers: {"Authorization" => "Basic QUMxMjM6YmZzZWs="}).
            to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://whdbtestfake.signalwire.com/api/laml/2010-04-01/Accounts/AC123/Messages/SMabcxyz/Media?Page=1&PageSize=2").
            to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://whdbtestfake.signalwire.com/api/laml/2010-04-01/Accounts/AC123/Messages/SMabcxyz/Media?Page=2&PageSize=2").
            to_return(status: 200, body: page3_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_empty_requests
      return [
        stub_request(:get, "https://whdbtestfake.signalwire.com/api/laml/2010-04-01/Accounts/AC123/Messages/SMabcxyz/Media").
            to_return(status: 200, body: page3_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://whdbtestfake.signalwire.com/api/laml/2010-04-01/Accounts/AC123/Messages/SMabcxyz/Media").
          to_return(status: 402, body: "woah")
    end

    def setup_auth(message_sint)
      sint.update(api_url: "" , backfill_key: "", backfill_secret: "" )
      message_sint.update(api_url: "whdbtestfake" , backfill_key: "AC123", backfill_secret: "bfsek" )
    end

    def insert_required_data_callback
      lambda do |dep|
        setup_auth(dep.service_integration)
        described_class.dependency_upsert_disabled = true
        dep.upsert_webhook_body(message_with_media(1))
      ensure
        described_class.dependency_upsert_disabled = false
      end
    end

    it "does not alert on backfill auth errors" do
      create_all_dependencies(sint)
      setup_dependencies(sint, insert_required_data_callback)

      req = stub_request(:get, "https://whdbtestfake.signalwire.com/api/laml/2010-04-01/Accounts/AC123/Messages/SMabcxyz/Media").
        to_return(status: 401, body: "woah")
      backfill(sint)
      expect([req]).to all(have_been_made)
    end

    it "raises on other backfill http errors" do
      create_all_dependencies(sint)
      setup_dependencies(sint, insert_required_data_callback)
      expect(Webhookdb::Backfiller).to receive(:do_retry_wait).twice

      req = stub_request(:get, "https://whdbtestfake.signalwire.com/api/laml/2010-04-01/Accounts/AC123/Messages/SMabcxyz/Media").
        to_return(status: 402, body: "woah")
      expect { backfill(sint) }.to raise_error(/status: 402/)
      expect(req).to have_been_made.times(3)
    end

    it "backfills for messages with media created after the latest media row was created" do
      create_all_dependencies(sint)
      cb = lambda do |dep|
        described_class.dependency_upsert_disabled = true
        dep.upsert_webhook_body(message_with_media(1, sid: "old", date_created: "Fri, 24 May 2019 17:44:46 +0000"))
        dep.upsert_webhook_body(message_with_media(1, sid: "mid", date_created: "Fri, 24 May 2020 17:44:46 +0000"))
        dep.upsert_webhook_body(message_with_media(1, sid: "new1", date_created: "Fri, 24 May 2021 17:44:46 +0000"))
        dep.upsert_webhook_body(message_with_media(1, sid: "new2", date_created: "Fri, 24 May 2022 17:44:46 +0000"))
        dep.upsert_webhook_body(
          message_with_media(0, sid: "new-nomedia", date_created: "Fri, 24 May 2024 17:44:46 +0000"),
        )
      ensure
        described_class.dependency_upsert_disabled = false
      end
      setup_dependencies(sint, cb)
      setup_auth(sint.depends_on)
      sint.replicator.upsert_webhook_body(
        {
          sid: "existing",
          date_created: "Sat, 25 May 2020 05:07:56 +0000",
          date_updated: "Sat, 17 May 2025 05:07:57 +0000",
          account_sid: "AC123",
          parent_sid: "mid",
          content_type: "image/jpeg",
          uri: "/api/laml/2010-04-01/Accounts/AC123/Messages/SMabcxyz/Media/f192e224-e810-4a7b-ab57-0a7942415631.json",
        }.as_json,
      )
      reqs = [
        stub_request(:get, "https://whdbtestfake.signalwire.com/api/laml/2010-04-01/Accounts/AC123/Messages/new1/Media").
          to_return(status: 200, body: <<~JSON, headers: {"Content-Type" => "application/json"}),
            {
              "media_list": [
                {
                  "sid": "new1-media1",
                  "date_created": "Sat, 17 May 2025 05:07:56 +0000",
                  "date_updated": "Sat, 17 May 2025 05:07:57 +0000",
                  "account_sid": "AC123",
                  "parent_sid": "new1",
                  "content_type": "image/jpeg",
                  "uri": "/api/laml/2010-04-01/Accounts/AC123/Messages/new1/Media/new1-media1.json"
                }
              ]
            }
          JSON
        stub_request(:get, "https://whdbtestfake.signalwire.com/api/laml/2010-04-01/Accounts/AC123/Messages/new2/Media").
          to_return(status: 200, body: <<~JSON, headers: {"Content-Type" => "application/json"}),
            {
              "media_list": [
                {
                  "sid": "new2-media1",
                  "date_created": "Sat, 17 May 2025 05:07:56 +0000",
                  "date_updated": "Sat, 17 May 2025 05:07:57 +0000",
                  "account_sid": "AC123",
                  "parent_sid": "new2",
                  "content_type": "image/jpeg",
                  "uri": "/api/laml/2010-04-01/Accounts/AC123/Messages/new1/Media/new2-media1.json"
                }
              ]
            }
          JSON
      ]
      backfill(sint)
      expect(reqs).to all(have_been_made)
      expect(svc.admin_dataset(&:all)).to contain_exactly(
        include(signalwire_id: "existing"),
        include(signalwire_id: "new1-media1"),
        include(signalwire_id: "new2-media1"),
      )
    end

    it "synchronously upserts media when a message row is upserted" do
      create_all_dependencies(sint)
      setup_dependencies(sint)
      reqs = [
        stub_request(:get, "https://whdbtestfake.signalwire.com/api/laml/2010-04-01/Accounts/AC123/Messages/new1/Media").
          to_return(status: 200, body: <<~JSON, headers: {"Content-Type" => "application/json"}),
            {
              "media_list": [
                {
                  "sid": "new1-media1",
                  "date_created": "Sat, 17 May 2025 05:07:56 +0000",
                  "date_updated": "Sat, 17 May 2025 05:07:57 +0000",
                  "account_sid": "AC123",
                  "parent_sid": "new1",
                  "content_type": "image/jpeg",
                  "uri": "/api/laml/2010-04-01/Accounts/AC123/Messages/new1/Media/new1-media1.json"
                }
              ]
            }
          JSON
      ]
      setup_auth(sint.depends_on)
      sint.depends_on.replicator.upsert_webhook_body(
        message_with_media(1, sid: "new1", date_created: "Fri, 24 May 2019 17:44:46 +0000"),
      )
      expect(reqs).to all(have_been_made)
      expect(svc.admin_dataset(&:all)).to contain_exactly(
        include(signalwire_id: "new1-media1"),
      )
    end
  end

  describe "state machine calculation" do
    let(:message_sint) { Webhookdb::Fixtures.service_integration.create(service_name: "signalwire_message_v1") }
    let(:sint) do
      Webhookdb::Fixtures.service_integration.create(service_name: "signalwire_media_v1", depends_on: message_sint)
    end
    let(:svc) { Webhookdb::Replicator.create(sint) }

    describe "calculate_backfill_state_machine" do
      it "prompts for dependencies" do
        sint.update(depends_on: nil)
        message_sint.destroy
        sm = sint.replicator.calculate_backfill_state_machine
        expect(sm).to have_attributes(output: /You don't have any SignalWire Message integrations yet/)
      end

      it "succeeds and prints a success response if the dependency is set" do
        sm = sint.replicator.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          complete: true,
          output: /We will start replicating SignalWire Medias into your WebhookDB database/,
        )
      end
    end
  end
end
