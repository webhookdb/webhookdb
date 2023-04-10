# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::SponsyPlacementV1, :db do
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }
  let(:publication_sint) { fac.create(service_name: "sponsy_publication_v1", backfill_secret: "apikey") }
  let(:publication_svc) { publication_sint.replicator }
  let(:sint) { fac.depending_on(publication_sint).create(service_name: "sponsy_placement_v1").refresh }
  let(:svc) { sint.replicator }
  let(:publication_id1) { "pubid1" }
  let(:publication_id2) { "pubid2" }
  let(:headers) { {"Content-Type" => "application/json"} }
  let(:root_url) { "https://api.getsponsy.com/v1/publications" }
  let(:querystr) { "limit=100&orderBy=updatedAt&orderDirection=DESC" }

  def insert_publication_rows(dep_svc)
    dep_svc.admin_dataset do |ds|
      ds.multi_insert(
        [
          {data: "{}", sponsy_id: publication_id1},
          {data: "{}", sponsy_id: publication_id2},
        ],
      )
      return ds.order(:pk).last
    end
  end

  def make_body(dates, cursor)
    data = dates.map do |date|
      {
        id: "#{date}-#{SecureRandom.hex(4)}",
        createdAt: "#{date}T22:07:36.241Z",
        updatedAt: "#{date}T19:27:34.962Z",
        name: "Sent",
        slug: "sent",
        color: "#2A0481",
        order: 3,
      }
    end
    return {data:, cursor: {afterCursor: cursor}}.to_json
  end

  it_behaves_like "a replicator", "sponsy_placement_v1" do
    let(:body) do
      JSON.parse(<<~J)
        {
          "id": "9782fb8c-5a69-4f01-b95c-f9b70b0412c8",
          "createdAt": "2022-05-16T18:04:56.138Z",
          "updatedAt": "2022-05-16T18:04:56.138Z",
          "name": "In Review",
          "slug": "in-review",
          "color": "#ff4785",
          "order": 3,
          "publication_id": "added-for-spec"
        }
      J
    end
  end

  it_behaves_like "a replicator that prevents overwriting new data with old", "sponsy_placement_v1" do
    let(:old_body) do
      JSON.parse(<<~J)
        {
          "id": "9782fb8c-5a69-4f01-b95c-f9b70b0412c8",
          "createdAt": "2022-05-16T18:04:56.138Z",
          "updatedAt": "2022-05-16T18:04:56.138Z",
          "name": "In Review",
          "slug": "in-review",
          "color": "#ff4785",
          "order": 3,
          "publication_id": "added-for-spec"
        }
      J
    end
    let(:new_body) do
      JSON.parse(<<~J)
        {
          "id": "9782fb8c-5a69-4f01-b95c-f9b70b0412c8",
          "createdAt": "2022-05-16T18:04:56.138Z",
          "updatedAt": "2022-05-26T18:04:56.138Z",
          "name": "In Review",
          "slug": "in-review",
          "color": "#ff4785",
          "order": 4,
          "publication_id": "added-for-spec"
        }
      J
    end
  end

  it_behaves_like "a replicator dependent on another", "sponsy_placement_v1", "sponsy_publication_v1" do
    let(:no_dependencies_message) { "This integration requires Sponsy Publications to sync" }
  end

  it_behaves_like "a replicator that can backfill", "sponsy_placement_v1" do
    let(:expected_items_count) { 8 }

    def insert_required_data_callback
      return lambda do |dep_svc|
        dep_svc.root_integration.update(backfill_secret: "sponsyapitoken")
        insert_publication_rows(dep_svc)
      end
    end

    def stub_service_requests
      return [
        stub_request(:get, "#{root_url}/#{publication_id1}/placements?afterCursor=&#{querystr}").
            with(headers: {"X-Api-Key" => "sponsyapitoken"}).
            to_return(status: 200, body: make_body(["2022-04-10", "2022-04-09"], "curs1a"), headers:),
        stub_request(:get, "#{root_url}/#{publication_id1}/placements?afterCursor=curs1a&#{querystr}").
            to_return(status: 200, body: make_body(["2022-04-08", "2022-04-07"], "curs1b"), headers:),
        stub_request(:get, "#{root_url}/#{publication_id1}/placements?afterCursor=curs1b&#{querystr}").
            to_return(status: 200, body: make_body([], nil), headers:),
        stub_request(:get, "#{root_url}/#{publication_id2}/placements?afterCursor=&#{querystr}").
            with(headers: {"X-Api-Key" => "sponsyapitoken"}).
            to_return(status: 200, body: make_body(["2022-04-10", "2022-04-09"], "curs2a"), headers:),
        stub_request(:get, "#{root_url}/#{publication_id2}/placements?afterCursor=curs2a&#{querystr}").
            to_return(status: 200, body: make_body(["2022-04-08", "2022-04-07"], "curs2b"), headers:),
        stub_request(:get, "#{root_url}/#{publication_id2}/placements?afterCursor=curs2b&#{querystr}").
            to_return(status: 200, body: make_body([], nil), headers:),
      ]
    end

    def stub_empty_requests
      return [
        stub_request(:get, "#{root_url}/#{publication_id1}/placements?afterCursor=&#{querystr}").
            to_return(status: 200, body: make_body([], nil), headers:),
        stub_request(:get, "#{root_url}/#{publication_id2}/placements?afterCursor=&#{querystr}").
            to_return(status: 200, body: make_body([], nil), headers:),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "#{root_url}/#{publication_id1}/placements?afterCursor=&#{querystr}").
          to_return(status: 503, body: "woah")
    end
  end

  it_behaves_like "a replicator that can backfill incrementally", "sponsy_placement_v1" do
    let(:last_backfilled) { "2022-09-01T18:00:00Z" }
    let(:expected_new_items_count) { 4 }
    let(:expected_old_items_count) { 2 }

    def insert_required_data_callback
      return lambda do |dep_svc|
        dep_svc.root_integration.update(backfill_secret: "sponsyapitoken")
        insert_publication_rows(dep_svc)
      end
    end

    def stub_service_requests(partial:)
      if partial
        return [
          stub_request(:get, "#{root_url}/#{publication_id1}/placements?afterCursor=&#{querystr}").
              to_return(status: 200, body: make_body(["2022-09-02"], "cursor1a"), headers:),
          stub_request(:get, "#{root_url}/#{publication_id1}/placements?afterCursor=cursor1a&#{querystr}").
              to_return(status: 200, body: make_body(["2022-09-01"], nil), headers:),
          stub_request(:get, "#{root_url}/#{publication_id2}/placements?afterCursor=&#{querystr}").
              to_return(status: 200, body: make_body(["2022-09-02"], "cursor2a"), headers:),
          stub_request(:get, "#{root_url}/#{publication_id2}/placements?afterCursor=cursor2a&#{querystr}").
              to_return(status: 200, body: make_body(["2022-09-01"], nil), headers:),
        ]
      end
      return [
        stub_request(:get, "#{root_url}/#{publication_id1}/placements?afterCursor=&#{querystr}").
            to_return(status: 200, body: make_body(["2022-09-02"], "cursor1a"), headers:),
        stub_request(:get, "#{root_url}/#{publication_id1}/placements?afterCursor=cursor1a&#{querystr}").
            to_return(status: 200, body: make_body(["2022-09-01"], "cursor1b"), headers:),
        stub_request(:get, "#{root_url}/#{publication_id1}/placements?afterCursor=cursor1b&#{querystr}").
            to_return(status: 200, body: make_body(["2022-08-31"], nil), headers:),
        stub_request(:get, "#{root_url}/#{publication_id2}/placements?afterCursor=&#{querystr}").
            to_return(status: 200, body: make_body(["2022-09-02"], "cursor2a"), headers:),
        stub_request(:get, "#{root_url}/#{publication_id2}/placements?afterCursor=cursor2a&#{querystr}").
            to_return(status: 200, body: make_body(["2022-09-01"], "cursor2b"), headers:),
        stub_request(:get, "#{root_url}/#{publication_id2}/placements?afterCursor=cursor2b&#{querystr}").
            to_return(status: 200, body: make_body(["2022-08-31"], nil), headers:),
      ]
    end
  end

  it_behaves_like "a backfill replicator that requires credentials from a dependency", "sponsy_placement_v1" do
    let(:error_message) { /This Sponsy/ }
    def strip_auth(sint)
      sint.replicator.root_integration.update(backfill_secret: "")
    end
  end

  describe "specialized backfill behavior" do
    it "inserts the publication id into the body before upsert" do
      sint.organization.prepare_database_connections
      req = stub_request(:get, "#{root_url}/#{publication_id1}/placements?afterCursor=&#{querystr}").
        to_return(status: 200, body: make_body(["2022-09-02"], nil), headers:)
      create_all_dependencies(sint)
      setup_dependency(sint, lambda do |dep_svc|
        dep_svc.admin_dataset { |ds| ds.insert(data: "{}", sponsy_id: publication_id1) }
      end,)
      svc.create_table
      svc.backfill
      expect(req).to have_been_made
      expect(svc.admin_dataset(&:all)).to contain_exactly(
        include(
          sponsy_id: start_with("2022-09-02-"),
          publication_id: "pubid1",
        ),
      )
    ensure
      sint.organization.remove_related_database
    end
  end

  describe "state machine calculation" do
    describe "calculate_create_state_machine" do
      it "prompts for dependencies" do
        sint.update(depends_on: nil)
        publication_sint.destroy
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(output: /You don't have any Sponsy Publication integrations yet/)
      end

      it "succeeds and prints a success response if the dependency is set" do
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          complete: true,
          output: /You are all set/,
        )
      end
    end

    describe "calculate_backfill_state_machine" do
      it "returns org database info" do
        sm = sint.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          complete: true,
          output: /We will start backfilling Sponsy Placements into your WebhookDB database/,
        )
      end
    end
  end
end
