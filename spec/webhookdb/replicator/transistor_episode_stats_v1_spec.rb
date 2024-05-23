# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::TransistorEpisodeStatsV1, :db do
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:episode_id_one) { SecureRandom.hex(5) }
  let(:episode_id_two) { SecureRandom.hex(5) }
  let(:episode_sint) { fac.create(service_name: "transistor_episode_v1") }
  let(:episode_svc) { episode_sint.replicator }
  let(:sint) { fac.depending_on(episode_sint).create(service_name: "transistor_episode_stats_v1").refresh }
  let(:svc) { sint.replicator }
  let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }

  def insert_episode_rows(dependency_svc)
    dependency_svc.admin_dataset do |ds|
      ds.multi_insert([
                        {
                          data: "{}",
                          created_at: DateTime.new(2021, 1, 1),
                          transistor_id: episode_id_one,
                        },
                        {
                          data: "{}",
                          created_at: DateTime.new(2021, 1, 1),
                          transistor_id: episode_id_two,
                        },
                      ])
      return ds.order(:pk).last
    end
  end

  it_behaves_like "a replicator" do
    let(:body) do
      JSON.parse(<<~J)
        {
           "episode_id":"abc123",
           "date":"03-09-2021",
           "downloads":10
        }
      J
    end
  end

  it_behaves_like "a replicator dependent on another",
                  "transistor_episode_v1" do
    let(:no_dependencies_message) { "This integration requires Transistor Episodes to sync" }
  end

  it_behaves_like "a replicator that can backfill" do
    let(:page1_response) do
      <<~R
        {
           "data":{
              "id":"#{episode_id_one}",
              "type":"episode_analytics",
              "attributes":{
                 "downloads":[
                    {
                       "date":"03-09-2021",
                       "downloads":10
                    },
                    {
                       "date":"04-09-2021",
                       "downloads":11
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
                 "id":"#{episode_id_one}",
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
    let(:page2_response) do
      <<~R
        {
           "data":{
              "id":"#{episode_id_two}",
              "type":"episode_analytics",
              "attributes":{
                 "downloads":[
                    {
                       "date":"05-09-2021",
                       "downloads":12
                    },
                    {
                       "date":"06-09-2021",
                       "downloads":13
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
                 "id":"#{episode_id_two}",
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
    let(:expected_items_count) { 4 }

    def insert_required_data_callback
      return ->(ep_svc) { insert_episode_rows(ep_svc) }
    end

    def stub_service_requests
      return [
        stub_request(:get, "https://api.transistor.fm/v1/analytics/episodes/#{episode_id_one}").
            to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://api.transistor.fm/v1/analytics/episodes/#{episode_id_two}").
            to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_empty_requests
      return [
        stub_request(:get, "https://api.transistor.fm/v1/analytics/episodes/#{episode_id_one}").
            to_return(status: 200, body: {data: {attributes: {}}}.to_json, headers: json_headers),
        stub_request(:get, "https://api.transistor.fm/v1/analytics/episodes/#{episode_id_two}").
            to_return(status: 200, body: {data: {attributes: {}}}.to_json, headers: json_headers),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.transistor.fm/v1/analytics/episodes/#{episode_id_one}").
          to_return(status: 503, body: "whoo")
    end
  end

  describe "state machine calculation" do
    describe "calculate_backfill_state_machine" do
      it "prompts for dependencies" do
        sint.update(depends_on: nil)
        episode_sint.destroy
        sm = sint.replicator.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          output: match("This integration requires Transistor Episodes to sync"),
        )
      end

      it "succeeds and prints a success response if the dependency is set" do
        sint.webhook_secret = "whsec_abcasdf"
        sm = sint.replicator.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          complete: true,
          output: match("Great! That's all the information we need."),
        )
      end
    end
  end

  describe "specialized table behavior" do
    before(:each) do
      org.prepare_database_connections
    end

    after(:each) do
      org.remove_related_database
    end

    let(:old_item) do
      {
        "date" => "03-09-2021",
        "downloads" => 0,
      }
    end

    let(:new_item) do
      {
        "date" => "03-09-2021",
        "downloads" => 2,
      }
    end

    it "will upsert based on episode and date_id" do
      episode_svc.create_table
      insert_episode_rows(episode_svc)
      svc.create_table

      backfiller = Webhookdb::Replicator::TransistorEpisodeStatsV1::EpisodeStatsBackfiller.new(
        episode_svc:,
        episode_stats_svc: svc,
        episode_id: episode_id_one,
        episode_created_at: nil,
      )

      backfiller.handle_item(old_item)
      expect(svc.readonly_dataset(&:all)).to contain_exactly(
        include(
          episode_id: episode_id_one,
          date: Date.new(2021, 9, 3),
          downloads: 0,
          row_updated_at: be_within(1.seconds).of(DateTime.now),
        ),
      )

      backfiller.handle_item(new_item)
      expect(svc.readonly_dataset(&:all)).to contain_exactly(
        include(
          episode_id: episode_id_one,
          date: Date.new(2021, 9, 3),
          downloads: 2,
          row_updated_at: be_within(1.seconds).of(DateTime.now),
        ),
      )
    end
  end
end
