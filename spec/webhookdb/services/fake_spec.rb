# frozen_string_literal: true

require "support/shared_examples_for_services"

RSpec.describe Webhookdb::Services, :db do
  it "raises for an invalid service" do
    sint = Webhookdb::Fixtures.service_integration.create(service_name: "nope")
    expect { described_class.service_instance(sint) }.to raise_error(described_class::InvalidService)
  end

  describe "fake v1" do
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
      before(:each) do
        Webhookdb::Services::Fake.reset
        Webhookdb::Services::Fake.backfill_responses = {
          nil => [page1_items, "token1"],
          "token1" => [page2_items, "token2"],
          "token2" => [[], nil],
        }
      end
    end

    it_behaves_like "a service implementation that upserts webhooks only under specific conditions", "fake_v1" do
      before(:each) do
        Webhookdb::Services::Fake.reset
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
      before(:each) do
        Webhookdb::Services::FakeWithEnrichments.reset
      end
      let(:enrichment_tables) { Webhookdb::Services::FakeWithEnrichments.enrichment_tables }
      let(:body) { {"my_id" => "abc", "at" => "Thu, 30 Jul 2015 21:12:33 +0000"} }
      def assert_is_enriched(row)
        expect(row[:data]["enrichment"]).to eq({"extra" => "abc"})
      end

      def assert_enrichment_after_insert(db)
        expect(db[:fake_v1_enrichments].all).to have_length(1)
      end
    end
  end
end
