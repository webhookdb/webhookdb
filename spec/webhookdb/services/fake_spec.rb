# frozen_string_literal: true

require "support/shared_examples_for_services"

RSpec.describe Webhookdb::Services::Fake, :db do
  before(:each) do
    Webhookdb::Services::Fake.reset
    Webhookdb::Services::FakeWithEnrichments.reset
  end
  it_behaves_like "a service implementation", "fake_v1" do
    let(:body) do
      {
        "my_id" => "abc",
        "at" => "Thu, 30 Jul 2015 21:12:33 +0000",
      }
    end
  end

  it_behaves_like "a service implementation that prevents overwriting new data with old", "fake_v1" do
    let(:old_body) do
      {
        "my_id" => "abc",
        "at" => "Thu, 30 Jul 2015 21:12:33 +0000",
      }
    end
    let(:new_body) do
      {
        "my_id" => "abc",
        "at" => "Thu, 30 Jul 2016 21:12:33 +0000",
      }
    end
  end

  it_behaves_like "a service implementation that can backfill", "fake_v1" do
    let(:page1_items) do
      [
        {"my_id" => "1", "at" => "Thu, 30 Jul 2015 21:12:33 +0000"},
        {"my_id" => "2", "at" => "Thu, 30 Jul 2015 21:12:33 +0000"},
      ]
    end
    let(:page2_items) do
      [
        {"my_id" => "3", "at" => "Thu, 30 Jul 2015 21:12:33 +0000"},
        {"my_id" => "4", "at" => "Thu, 30 Jul 2015 21:12:33 +0000"},
      ]
    end
    let(:expected_items_count) { 4 }
    def stub_service_requests
      return [
        stub_request(:get, "https://fake-integration/?token=").
            to_return(status: 200, body: [page1_items,
                                          "p2",].to_json, headers: {"Content-Type" => "application/json"},),
        stub_request(:get, "https://fake-integration/?token=p2").
            to_return(status: 200, body: [page2_items, nil].to_json, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_service_request_error
      stub_request(:get, "https://fake-integration/?token=").
        to_return(status: 500, body: "erm")
    end
  end

  it_behaves_like "a service implementation that upserts webhooks only under specific conditions", "fake_v1" do
    before(:each) do
      Webhookdb::Services::Fake.prepare_for_insert_hook = ->(_h) {}
    end
    let(:incorrect_webhook) do
      {
        "my_id" => "abc",
        "at" => "Thu, 30 Jul 2015 21:12:33 +0000",
      }
    end
  end

  it_behaves_like "a service implementation that uses enrichments", "fake_with_enrichments_v1" do
    let(:enrichment_tables) { Webhookdb::Services::FakeWithEnrichments.enrichment_tables }
    let(:body) { {"my_id" => "abc", "at" => "Thu, 30 Jul 2015 21:12:33 +0000"} }

    def stub_service_request
      return stub_request(:get, "https://fake-integration/enrichment/abc").
          to_return(status: 200, body: {extra: "abc"}.to_json, headers: {"Content-Type" => "application/json"})
    end

    def stub_service_request_error
      return stub_request(:get, "https://fake-integration/enrichment/abc").
          to_return(status: 500, body: "gerd")
    end

    def assert_is_enriched(row)
      expect(row[:data]["enrichment"]).to eq({"extra" => "abc"})
    end

    def assert_enrichment_after_insert(db)
      expect(db[:fake_v1_enrichments].all).to have_length(1)
    end
  end

  describe "base class functionality" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create }
    let(:fake) { sint.service_instance }
    describe "verify_backfill_credentials" do
      before(:each) do
        fake.define_singleton_method(:_verify_backfill_408_err_msg) do
          "custom 408 message"
        end
        fake.define_singleton_method(:_verify_backfill_err_msg) do
          "default message"
        end
      end
      it "verifies on success" do
        described_class.stub_backfill_request([])
        result = fake.verify_backfill_credentials
        expect(result).to include(verified: true, message: "")
      end
      it "uses a default error message" do
        described_class.stub_backfill_request([], status: 401)
        result = fake.verify_backfill_credentials
        expect(result).to include(verified: false, message: "default message")
      end
      it "can use code-specific error messages" do
        described_class.stub_backfill_request([], status: 408)
        result = fake.verify_backfill_credentials
        expect(result).to include(verified: false, message: "custom 408 message")
      end
    end
  end
end
