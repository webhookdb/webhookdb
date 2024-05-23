# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::GithubRepositoryEventV1, :db do
  it_behaves_like "a replicator", supports_row_diff: false do
    let(:body) do
      JSON.parse(<<~JSON)
        {
          "id": "22249084964",
          "type": "PushEvent",
          "actor": {
            "id": 583231,
            "login": "octocat",
            "display_login": "octocat",
            "gravatar_id": "",
            "url": "https://api.github.com/users/octocat",
            "avatar_url": "https://avatars.githubusercontent.com/u/583231?v=4"
          },
          "repo": {
            "id": 1296269,
            "name": "octocat/Hello-World",
            "url": "https://api.github.com/repos/octocat/Hello-World"
          },
          "payload": {
            "push_id": 10115855396,
            "size": 1,
            "distinct_size": 1,
            "ref": "refs/heads/master"
          },
          "public": true,
          "created_at": "2022-06-09T12:47:28Z"
        }
      JSON
    end
  end

  # Events are (I think) immutable
  # it_behaves_like "a replicator that prevents overwriting new data with old"

  it_behaves_like "a replicator that may have a minimal body" do
    let(:body) do
      JSON.parse(<<~JSON)
        {
          "id": "22249084964",
          "type": "PushEvent",
          "public": true,
          "created_at": "2022-06-09T12:47:28Z"
        }
      JSON
    end
  end

  # Activity events are backfill-only
  # it_behaves_like "a replicator that deals with resources and wrapped events"

  # This is tested through github_issue_v1
  # it_behaves_like "a replicator that verifies backfill secrets"

  it_behaves_like "a replicator that can backfill" do
    let(:api_url) { "my/code" }
    let(:page1_response) do
      <<~JSON
        [
          {
            "id": "1",
            "type": "PushEvent",
            "actor": {
              "id": 583231,
              "login": "octocat",
              "display_login": "octocat",
              "gravatar_id": "",
              "url": "https://api.github.com/users/octocat",
              "avatar_url": "https://avatars.githubusercontent.com/u/583231?v=4"
            },
            "repo": {
              "id": 1296269,
              "name": "octocat/Hello-World",
              "url": "https://api.github.com/repos/octocat/Hello-World"
            },
            "payload": {
              "push_id": 10115855396,
              "size": 1,
              "distinct_size": 1,
              "ref": "refs/heads/master"
            },
            "public": true,
            "created_at": "2022-06-09T12:47:28Z"
          },
          {
            "id": "2",
            "type": "PushEvent",
            "actor": {
              "id": 583231,
              "login": "octocat",
              "display_login": "octocat",
              "gravatar_id": "",
              "url": "https://api.github.com/users/octocat",
              "avatar_url": "https://avatars.githubusercontent.com/u/583231?v=4"
            },
            "repo": {
              "id": 1296269,
              "name": "octocat/Hello-World",
              "url": "https://api.github.com/repos/octocat/Hello-World"
            },
            "payload": {
              "push_id": 10115855396,
              "size": 1,
              "distinct_size": 1,
              "ref": "refs/heads/master"
            },
            "public": true,
            "created_at": "2022-06-09T12:47:28Z"
          }
        ]
      JSON
    end
    let(:page2_response) do
      <<~JSON
        [
          {
            "id": "3",
            "type": "PushEvent",
            "actor": {
              "id": 583231,
              "login": "octocat",
              "display_login": "octocat",
              "gravatar_id": "",
              "url": "https://api.github.com/users/octocat",
              "avatar_url": "https://avatars.githubusercontent.com/u/583231?v=4"
            },
            "repo": {
              "id": 1296269,
              "name": "octocat/Hello-World",
              "url": "https://api.github.com/repos/octocat/Hello-World"
            },
            "payload": {
              "push_id": 10115855396,
              "size": 1,
              "distinct_size": 1,
              "ref": "refs/heads/master"
            },
            "public": true,
            "created_at": "2022-06-09T12:47:28Z"
          }
        ]
      JSON
    end
    let(:expected_items_count) { 3 }
    def stub_service_requests
      return [
        stub_request(:get, "https://api.github.com/repos/my/code/events?per_page=100").
            to_return(
              status: 200,
              body: page1_response,
              headers: {
                "Content-Type" => "application/json",
                "Link" => '<https://api.github.com/repos/my/code/events?page=2>; rel="next"',
              },
            ),
        stub_request(:get, "https://api.github.com/repos/my/code/events?page=2").
            to_return(status: 200, body: page2_response, headers: json_headers),
      ]
    end

    def stub_empty_requests
      return [
        stub_request(:get, "https://api.github.com/repos/my/code/events?per_page=100").
            to_return(status: 200, body: "[]", headers: json_headers),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.github.com/repos/my/code/events?per_page=100").
          to_return(status: 400, body: "fuuu")
    end
  end

  it_behaves_like "a replicator that can backfill incrementally" do
    let(:api_url) { "my/code" }
    let(:today) { Time.parse("2020-11-22T18:00:00Z") }
    let(:page1_response) do
      <<~JSON
        [
          {
            "id": "1",
            "type": "PushEvent",
            "actor": {
              "id": 583231,
              "login": "octocat",
              "display_login": "octocat",
              "gravatar_id": "",
              "url": "https://api.github.com/users/octocat",
              "avatar_url": "https://avatars.githubusercontent.com/u/583231?v=4"
            },
            "repo": {
              "id": 1296269,
              "name": "octocat/Hello-World",
              "url": "https://api.github.com/repos/octocat/Hello-World"
            },
            "payload": {
              "push_id": 10115855396,
              "size": 1,
              "distinct_size": 1,
              "ref": "refs/heads/master"
            },
            "public": true,
            "created_at": "2022-06-09T12:47:28Z"
          }
        ]
      JSON
    end
    let(:page2_response) do
      <<~JSON
        [
          {
            "id": "2",
            "type": "PushEvent",
            "actor": {
              "id": 583231,
              "login": "octocat",
              "display_login": "octocat",
              "gravatar_id": "",
              "url": "https://api.github.com/users/octocat",
              "avatar_url": "https://avatars.githubusercontent.com/u/583231?v=4"
            },
            "repo": {
              "id": 1296269,
              "name": "octocat/Hello-World",
              "url": "https://api.github.com/repos/octocat/Hello-World"
            },
            "payload": {
              "push_id": 10115855396,
              "size": 1,
              "distinct_size": 1,
              "ref": "refs/heads/master"
            },
            "public": true,
            "created_at": "2022-06-09T12:47:28Z"
          }
        ]
      JSON
    end
    let(:page3_response) do
      <<~JSON
        [
          {
            "id": "3",
            "type": "PushEvent",
            "actor": {
              "id": 583231,
              "login": "octocat",
              "display_login": "octocat",
              "gravatar_id": "",
              "url": "https://api.github.com/users/octocat",
              "avatar_url": "https://avatars.githubusercontent.com/u/583231?v=4"
            },
            "repo": {
              "id": 1296269,
              "name": "octocat/Hello-World",
              "url": "https://api.github.com/repos/octocat/Hello-World"
            },
            "payload": {
              "push_id": 10115855396,
              "size": 1,
              "distinct_size": 1,
              "ref": "refs/heads/master"
            },
            "public": true,
            "created_at": "2022-06-09T12:47:28Z"
          }
        ]
      JSON
    end
    let(:last_backfilled) { "2019-05-15T18:00:00Z" }
    let(:expected_old_items_count) { 2 }
    let(:expected_new_items_count) { 1 }

    around(:each) do |example|
      Timecop.travel(today) do
        example.run
      end
    end

    def stub_service_requests(partial:)
      if partial
        return [
          stub_request(:get, "https://api.github.com/repos/my/code/events?per_page=100").
              to_return(status: 200, body: page3_response, headers: json_headers),
        ]
      end
      return [
        stub_request(:get, "https://api.github.com/repos/my/code/events?per_page=100").
            to_return(
              status: 200,
              body: page1_response,
              headers: {
                "Content-Type" => "application/json",
                "link" => '<https://api.github.com/repos/my/code/events?page=2>; rel="next"',
              },
            ),
        stub_request(:get, "https://api.github.com/repos/my/code/events?page=2").
            to_return(
              status: 200,
              body: page2_response,
              headers: {
                "Content-Type" => "application/json",
                "link" => '<https://api.github.com/repos/my/code/events?page=3>; rel="next"',
              },
            ),
        stub_request(:get, "https://api.github.com/repos/my/code/events?page=3").
            to_return(status: 200, body: page3_response, headers: json_headers),
      ]
    end
  end

  # Tested through github_issue
  # describe "webhook validation"
  # describe "state machine calculation"
end
