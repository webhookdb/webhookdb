# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.shared_examples "an Increase replicator dependent on events and increase_app_v1" do
  name = described_class.descriptor.name
  let(:increase_type) { doc_resource_body.fetch("type") }
  let(:list_path) { raise NotImplementedError, "like '/accounts'" }
  let(:denormalized_key) { raise NotImplementedError, "like 'account_number'" }
  let(:denormalized_value) { doc_resource_body.fetch(denormalized_key.to_s) }
  let(:doc_resource_json) { raise NotImplementedError, "json string from API docs" }
  let(:doc_resource_body) { JSON.parse(doc_resource_json) }
  let(:insertable_body) { doc_resource_body.merge("updated_at" => "2020-01-31T23:59:59Z") }
  let(:old_insertable_body) { doc_resource_body.merge("updated_at" => "2020-01-31T23:59:59Z") }
  let(:new_insertable_body) { doc_resource_body.merge("updated_at" => "2020-02-20T23:59:59Z") }
  let(:created_at_column) { :created_at }
  let(:event_item_id) { event_body.fetch("associated_object_id") }
  let(:event_body) { JSON.parse(<<~JSON) }
    {
      "associated_object_id": "#{increase_type}_yy0yirrxa4pblzl0k4op",
      "associated_object_type": "#{increase_type}",
      "category": "fake",
      "created_at": "2022-01-31T23:59:59Z",
      "id": "event_001dzz0r20rzr4zrhrr1364hy80",
      "type": "event"
    }
  JSON

  it_behaves_like "a replicator", name do
    let(:body) { insertable_body }
  end

  it_behaves_like "a replicator that prevents overwriting new data with old", name do
    let(:old_body) { old_insertable_body }
    let(:new_body) { new_insertable_body }
  end

  it_behaves_like "a replicator that uses enrichments", name, stores_enrichment_column: false do
    before(:each) do
      create_all_dependencies(sint).first.update(backfill_key: "access-tok", api_url: "https://api.increase.com")
    end

    let(:body) { event_body.merge("created_at" => "2012-01-31T23:59:59Z") }
    let(:response_json) { doc_resource_body.merge("created_at" => "2010-01-31T23:59:59Z").to_json }

    def stub_service_request
      return stub_request(:get, "https://api.increase.com#{list_path}/#{event_item_id}").
          to_return(
            status: 200,
            headers: {"Content-Type" => "application/json", "Authorization" => "Bearer access-tok"},
            body: response_json,
          )
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.increase.com#{list_path}/#{event_item_id}").
          to_return(status: 503, body: "nope")
    end

    def assert_is_enriched(row)
      expect(row).to include(
        created_at_column => match_time("2010-01-31T23:59:59Z"),
        svc._timestamp_column_name => match_time("2012-01-31T23:59:59Z"),
        denormalized_key => denormalized_value,
      )
    end
  end

  it_behaves_like "a replicator that can backfill", name do
    def create_all_dependencies(sint)
      r = super
      sint.depends_on&.update(backfill_key: "access-tok", api_url: "https://api.increase.com")
      return r
    end

    def backfill_items(id1, id2)
      return [id1, id2].map { |id| insertable_body.merge("id" => insertable_body["id"] + "-#{id}") }
    end

    let(:page1_response) { <<~JSON }
      {
        "data": #{backfill_items(0, 1).to_json},
        "response_metadata": {
          "next_cursor": "aW1pdCI6Mn0sInBvc2l0aW9uIjp7Im9mZnNldCI6NH19"
        }
      }
    JSON
    let(:page2_response) { <<~JSON }
      {
        "data": #{backfill_items(2, 3).to_json},
        "response_metadata": {
          "next_cursor": "lpYUWlPako5ZlEiLCJsaW1pdCI6Mn0sInBvc2l0aW9uIjp7Im9mZnNldCI6Nn19"
        }
      }
    JSON
    let(:page3_response) { <<~JSON }
      {
        "data": [],
        "response_metadata": {
          "next_cursor": null
        }
      }
    JSON
    let(:expected_items_count) { 4 }
    def stub_service_requests
      return [
        stub_request(:get, "https://api.increase.com#{list_path}").
            with(headers: {"Authorization" => "Bearer access-tok"}).
            to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://api.increase.com#{list_path}?cursor=aW1pdCI6Mn0sInBvc2l0aW9uIjp7Im9mZnNldCI6NH19").
            to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://api.increase.com#{list_path}?cursor=lpYUWlPako5ZlEiLCJsaW1pdCI6Mn0sInBvc2l0aW9uIjp7Im9mZnNldCI6Nn19").
            to_return(status: 200, body: page3_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_empty_requests
      return [
        stub_request(:get, "https://api.increase.com#{list_path}").
            to_return(status: 200, body: page3_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.increase.com#{list_path}").
          to_return(status: 400, body: "gah")
    end
  end
end
