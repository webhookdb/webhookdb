# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::GithubReleaseV1, :db do
  it_behaves_like "a replicator", "github_release_v1" do
    let(:supports_row_diff) { false }
    let(:body) do
      JSON.parse(<<~JSON)
        {
          "id": 1,
          "node_id": "MDc6UmVsZWFzZTE=",
          "tag_name": "v1.0.0",
          "target_commitish": "master",
          "name": "v1.0.0",
          "body": "Description of the release",
          "draft": false,
          "prerelease": false,
          "created_at": "2013-02-27T19:35:32Z",
          "published_at": "2013-02-27T19:35:32Z",
          "author": {
            "login": "octocat",
            "id": 1
          },
          "assets": [
            {
              "url": "https://api.github.com/repos/octocat/Hello-World/releases/assets/1",
              "browser_download_url": "https://github.com/octocat/Hello-World/releases/download/v1.0.0/example.zip",
              "id": 1
            }
          ]
        }
      JSON
    end
  end

  # Not supported for releases, we always stomp
  # it_behaves_like "a replicator that prevents overwriting new data with old", "github_release_v1"

  it_behaves_like "a replicator that may have a minimal body", "github_release_v1" do
    let(:body) do
      JSON.parse(<<~JSON)
        {
          "id": 1,
          "node_id": "MDc6UmVsZWFzZTE=",
          "tag_name": "v1.0.0",
          "target_commitish": "master",
          "name": "v1.0.0",
          "body": "Description of the release",
          "draft": false,
          "prerelease": false,
          "created_at": "2013-02-27T19:35:32Z",
          "published_at": "2013-02-27T19:35:32Z"
        }
      JSON
    end
  end
  it_behaves_like "a replicator that deals with resources and wrapped events", "github_release_v1" do
    let(:resource_json) { resource_in_envelope_json.fetch("release") }
    let(:resource_in_envelope_headers) { {"X-Github-Hook-Id" => "1"} }
    let(:resource_in_envelope_json) do
      JSON.parse(<<~JSON)
        {
          "action": "created",
          "sender": {},
          "release": {
            "id": 1,
            "node_id": "MDc6UmVsZWFzZTE=",
            "tag_name": "v1.0.0",
            "target_commitish": "master",
            "name": "v1.0.0",
            "body": "Description of the release",
            "draft": false,
            "prerelease": false,
            "created_at": "2013-02-27T19:35:32Z",
            "published_at": "2013-02-27T19:35:32Z",
            "author": {
              "login": "octocat",
              "id": 1
            },
            "assets": [
              {
                "url": "https://api.github.com/repos/octocat/Hello-World/releases/assets/1",
                "browser_download_url": "https://github.com/octocat/Hello-World/releases/download/v1.0.0/example.zip",
                "id": 1
              }
            ]
          }
        }
      JSON
    end
  end

  # This is tested through github_issue_v1
  # it_behaves_like "a replicator that verifies backfill secrets"

  it_behaves_like "a replicator that can backfill", "github_release_v1" do
    let(:api_url) { "my/code" }
    let(:page1_response) do
      <<~JSON
        [
          {
            "id": 1,
            "node_id": "MDc6UmVsZWFzZTE=",
            "tag_name": "v1.0.0",
            "target_commitish": "master",
            "name": "v1.0.0",
            "body": "Description of the release",
            "draft": false,
            "prerelease": false,
            "created_at": "2013-02-27T19:35:32Z",
            "published_at": "2013-02-27T19:35:32Z"
          },
          {
            "id": 2,
            "node_id": "MDc6UmVsZWFzZTE=",
            "tag_name": "v1.0.0",
            "target_commitish": "master",
            "name": "v1.0.0",
            "body": "Description of the release",
            "draft": false,
            "prerelease": false,
            "created_at": "2013-02-27T19:35:32Z",
            "published_at": "2013-02-27T19:35:32Z"
          }
        ]
      JSON
    end
    let(:page2_response) do
      <<~JSON
        [
          {
            "id": 3,
            "node_id": "MDc6UmVsZWFzZTE=",
            "tag_name": "v1.0.0",
            "target_commitish": "master",
            "name": "v1.0.0",
            "body": "Description of the release",
            "draft": false,
            "prerelease": false,
            "created_at": "2013-02-27T19:35:32Z",
            "published_at": "2013-02-27T19:35:32Z"
          }
        ]
      JSON
    end
    let(:expected_items_count) { 3 }
    def stub_service_requests
      return [
        stub_request(:get, "https://api.github.com/repos/my/code/releases?per_page=100").
            to_return(
              status: 200,
              body: page1_response,
              headers: {
                "Content-Type" => "application/json",
                "Link" => '<https://api.github.com/repos/my/code/releases?page=2>; rel="next"',
              },
            ),
        stub_request(:get, "https://api.github.com/repos/my/code/releases?page=2").
            to_return(status: 200, body: page2_response, headers: json_headers),
      ]
    end

    def stub_empty_requests
      return [
        stub_request(:get, "https://api.github.com/repos/my/code/releases?per_page=100").
            to_return(status: 200, body: "[]", headers: json_headers),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.github.com/repos/my/code/releases?per_page=100").
          to_return(status: 400, body: "fuuu")
    end
  end

  # Not supported for releases
  # it_behaves_like "a replicator that can backfill incrementally", "github_release_v1"

  # Tested through github_issue
  # describe "webhook validation"
  # describe "state machine calculation"
end
