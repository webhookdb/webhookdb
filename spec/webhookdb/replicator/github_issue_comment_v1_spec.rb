# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::GithubIssueCommentV1, :db do
  it_behaves_like "a replicator" do
    let(:body) do
      JSON.parse(<<~JSON)
        {
          "id": 1,
          "node_id": "MDEyOklzc3VlQ29tbWVudDE=",
          "url": "https://api.github.com/repos/octocat/Hello-World/issues/comments/1",
          "html_url": "https://github.com/octocat/Hello-World/issues/1347#issuecomment-1",
          "body": "Me too",
          "user": {
            "login": "octocat",
            "id": 1
          },
          "created_at": "2011-04-14T16:00:49Z",
          "updated_at": "2011-04-14T16:00:49Z",
          "issue_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347",
          "author_association": "COLLABORATOR"
        }
      JSON
    end
  end

  it_behaves_like "a replicator that prevents overwriting new data with old" do
    let(:old_body) do
      JSON.parse(<<~JSON)
        {
          "id": 1,
          "node_id": "MDEyOklzc3VlQ29tbWVudDE=",
          "url": "https://api.github.com/repos/octocat/Hello-World/issues/comments/1",
          "html_url": "https://github.com/octocat/Hello-World/issues/1347#issuecomment-1",
          "body": "Me too",
          "user": {
            "login": "octocat",
            "id": 1
          },
          "created_at": "2011-04-14T16:00:49Z",
          "updated_at": "2011-04-14T16:00:49Z",
          "issue_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347",
          "author_association": "COLLABORATOR"
        }
      JSON
    end
    let(:new_body) do
      JSON.parse(<<~JSON)
        {
          "id": 1,
          "node_id": "MDEyOklzc3VlQ29tbWVudDE=",
          "url": "https://api.github.com/repos/octocat/Hello-World/issues/comments/1",
          "html_url": "https://github.com/octocat/Hello-World/issues/1347#issuecomment-1",
          "body": "UPDATED",
          "user": {
            "login": "octocat",
            "id": 1
          },
          "created_at": "2011-04-14T16:00:49Z",
          "updated_at": "2012-04-14T16:00:49Z",
          "issue_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347",
          "author_association": "COLLABORATOR"
        }
      JSON
    end
  end

  it_behaves_like "a replicator that may have a minimal body" do
    let(:body) do
      JSON.parse(<<~JSON)
        {
          "id": 1,
          "node_id": "MDEyOklzc3VlQ29tbWVudDE=",
          "url": "https://api.github.com/repos/octocat/Hello-World/issues/comments/1",
          "html_url": "https://github.com/octocat/Hello-World/issues/1347#issuecomment-1",
          "body": "Me too",
          "created_at": "2011-04-14T16:00:49Z",
          "updated_at": "2011-04-14T16:00:49Z",
          "issue_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347",
          "author_association": "COLLABORATOR"
        }
      JSON
    end
  end
  it_behaves_like "a replicator that deals with resources and wrapped events" do
    let(:resource_json) { resource_in_envelope_json.fetch("comment") }
    let(:resource_in_envelope_headers) { {"X-Github-Hook-Id" => "1"} }
    let(:resource_in_envelope_json) do
      JSON.parse(<<~JSON)
        {
          "action": "created",
          "sender": {},
          "comment": {
            "id": 1,
            "node_id": "MDEyOklzc3VlQ29tbWVudDE=",
            "url": "https://api.github.com/repos/octocat/Hello-World/issues/comments/1",
            "html_url": "https://github.com/octocat/Hello-World/issues/1347#issuecomment-1",
            "body": "Me too",
            "user": {
              "login": "octocat",
              "id": 1
            },
            "created_at": "2011-04-14T16:00:49Z",
            "updated_at": "2011-04-14T16:00:49Z",
            "issue_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347",
            "author_association": "COLLABORATOR"
          }
        }
      JSON
    end
  end

  # This is tested through github_issue_v1
  # it_behaves_like "a replicator that verifies backfill secrets"

  it_behaves_like "a replicator that can backfill" do
    let(:api_url) { "my/code" }
    let(:page1_response) do
      <<~JSON
        [
          {
            "id": 1,
            "node_id": "MDEyOklzc3VlQ29tbWVudDE=",
            "url": "https://api.github.com/repos/octocat/Hello-World/issues/comments/1",
            "html_url": "https://github.com/octocat/Hello-World/issues/1347#issuecomment-1",
            "body": "Me too",
            "user": {
              "login": "octocat",
              "id": 1
            },
            "created_at": "2011-04-14T16:00:49Z",
            "updated_at": "2011-04-14T16:00:49Z",
            "issue_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347",
            "author_association": "COLLABORATOR"
          },
          {
            "id": 2,
            "node_id": "MDEyOklzc3VlQ29tbWVudDE=",
            "url": "https://api.github.com/repos/octocat/Hello-World/issues/comments/1",
            "html_url": "https://github.com/octocat/Hello-World/issues/1347#issuecomment-1",
            "body": "Me too",
            "user": {
              "login": "octocat",
              "id": 1
            },
            "created_at": "2011-04-14T16:00:49Z",
            "updated_at": "2011-04-14T16:00:49Z",
            "issue_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347",
            "author_association": "COLLABORATOR"
          }
        ]
      JSON
    end
    let(:page2_response) do
      <<~JSON
        [
          {
            "id": 3,
            "node_id": "MDEyOklzc3VlQ29tbWVudDE=",
            "url": "https://api.github.com/repos/octocat/Hello-World/issues/comments/1",
            "html_url": "https://github.com/octocat/Hello-World/issues/1347#issuecomment-1",
            "body": "Me too",
            "user": {
              "login": "octocat",
              "id": 1
            },
            "created_at": "2011-04-14T16:00:49Z",
            "updated_at": "2011-04-14T16:00:49Z",
            "issue_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347",
            "author_association": "COLLABORATOR"
          }
        ]
      JSON
    end
    let(:expected_items_count) { 3 }
    def stub_service_requests
      return [
        stub_request(:get, "https://api.github.com/repos/my/code/issues/comments?per_page=100").
            to_return(
              status: 200,
              body: page1_response,
              headers: {
                "Content-Type" => "application/json",
                "Link" => '<https://api.github.com/repos/my/code/issues/comments?page=2>; rel="next"',
              },
            ),
        stub_request(:get, "https://api.github.com/repos/my/code/issues/comments?page=2").
            to_return(status: 200, body: page2_response, headers: json_headers),
      ]
    end

    def stub_empty_requests
      return [
        stub_request(:get, "https://api.github.com/repos/my/code/issues/comments?per_page=100").
            to_return(status: 200, body: "[]", headers: json_headers),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.github.com/repos/my/code/issues/comments?per_page=100").
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
            "id": 1,
            "node_id": "MDEyOklzc3VlQ29tbWVudDE=",
            "url": "https://api.github.com/repos/octocat/Hello-World/issues/comments/1",
            "html_url": "https://github.com/octocat/Hello-World/issues/1347#issuecomment-1",
            "body": "Me too",
            "user": {
              "login": "octocat",
              "id": 1
            },
            "created_at": "2011-04-14T16:00:49Z",
            "updated_at": "2011-04-14T16:00:49Z",
            "issue_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347",
            "author_association": "COLLABORATOR"
          }
        ]
      JSON
    end
    let(:page2_response) do
      <<~JSON
        [
          {
            "id": 2,
            "node_id": "MDEyOklzc3VlQ29tbWVudDE=",
            "url": "https://api.github.com/repos/octocat/Hello-World/issues/comments/1",
            "html_url": "https://github.com/octocat/Hello-World/issues/1347#issuecomment-1",
            "body": "Me too",
            "user": {
              "login": "octocat",
              "id": 1
            },
            "created_at": "2011-04-14T16:00:49Z",
            "updated_at": "2011-04-14T16:00:49Z",
            "issue_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347",
            "author_association": "COLLABORATOR"
          }
        ]
      JSON
    end
    let(:page3_response) do
      <<~JSON
        [
          {
            "id": 3,
            "node_id": "MDEyOklzc3VlQ29tbWVudDE=",
            "url": "https://api.github.com/repos/octocat/Hello-World/issues/comments/1",
            "html_url": "https://github.com/octocat/Hello-World/issues/1347#issuecomment-1",
            "body": "Me too",
            "user": {
              "login": "octocat",
              "id": 1
            },
            "created_at": "2011-04-14T16:00:49Z",
            "updated_at": "2011-04-14T16:00:49Z",
            "issue_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347",
            "author_association": "COLLABORATOR"
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
          stub_request(:get, "https://api.github.com/repos/my/code/issues/comments?" \
                             "per_page=100&since=2019-05-15T18:00:00Z&sort=updated",).
              to_return(status: 200, body: page3_response, headers: json_headers),
        ]
      end
      return [
        stub_request(:get, "https://api.github.com/repos/my/code/issues/comments?per_page=100").
            to_return(
              status: 200,
              body: page1_response,
              headers: {
                "Content-Type" => "application/json",
                "link" => '<https://api.github.com/repos/my/code/issues/comments?page=2>; rel="next"',
              },
            ),
        stub_request(:get, "https://api.github.com/repos/my/code/issues/comments?page=2").
            to_return(
              status: 200,
              body: page2_response,
              headers: {
                "Content-Type" => "application/json",
                "link" => '<https://api.github.com/repos/my/code/issues/comments?page=3>; rel="next"',
              },
            ),
        stub_request(:get, "https://api.github.com/repos/my/code/issues/comments?page=3").
            to_return(status: 200, body: page3_response, headers: json_headers),
      ]
    end
  end

  # Tested through github_issue
  # describe "webhook validation"
  # describe "state machine calculation"
end
