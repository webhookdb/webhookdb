# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::GithubPullV1, :db do
  it_behaves_like "a replicator", "github_pull_v1" do
    let(:body) do
      JSON.parse(<<~JSON)
        {
          "url": "https://api.github.com/repos/octocat/Hello-World/pulls/1347",
          "id": 1,
          "node_id": "MDExOlB1bGxSZXF1ZXN0MQ==",
          "number": 1347,
          "state": "open",
          "locked": true,
          "title": "Amazing new feature",
          "user": {
            "login": "octocat",
            "id": 1
          },
          "body": "Please pull these awesome changes in!",
          "labels": [
            {
              "id": 208045946,
              "node_id": "MDU6TGFiZWwyMDgwNDU5NDY=",
              "url": "https://api.github.com/repos/octocat/Hello-World/labels/bug",
              "name": "bug",
              "description": "Something isn't working",
              "color": "f29513",
              "default": true
            }
          ],
          "milestone": {
            "url": "https://api.github.com/repos/octocat/Hello-World/milestones/1",
            "html_url": "https://github.com/octocat/Hello-World/milestones/v1.0",
            "labels_url": "https://api.github.com/repos/octocat/Hello-World/milestones/1/labels",
            "id": 1002604,
            "node_id": "MDk6TWlsZXN0b25lMTAwMjYwNA==",
            "number": 1
          },
          "active_lock_reason": "too heated",
          "created_at": "2011-01-26T19:01:12Z",
          "updated_at": "2011-01-26T19:01:12Z",
          "closed_at": "2011-01-26T19:01:12Z",
          "merged_at": "2011-01-26T19:01:12Z",
          "merge_commit_sha": "e5bd3914e2e596debea16f433f57875b5b90bcd6",
          "assignee": {
            "login": "octocat",
            "id": 1
          },
          "assignees": [
            {
              "login": "octocat",
              "id": 1
            },
            {
              "login": "hubot",
              "id": 1
            }
          ],
          "requested_reviewers": [
            {
              "login": "other_user",
              "id": 1
            }
          ],
          "requested_teams": [
            {
              "id": 1,
              "node_id": "MDQ6VGVhbTE="
            }
          ],
          "head": {
            "label": "octocat:new-topic",
            "ref": "new-topic",
            "sha": "6dcb09b5b57875f334f61aebed695e2e4193db5e",
            "user": {
              "login": "octocat",
              "id": 1
            },
            "repo": {
              "id": 1296269,
              "node_id": "MDEwOlJlcG9zaXRvcnkxMjk2MjY5"
            }
          },
          "base": {
            "label": "octocat:master",
            "ref": "master",
            "sha": "6dcb09b5b57875f334f61aebed695e2e4193db5e",
            "user": {
              "login": "octocat",
              "id": 1
            },
            "repo": {
              "id": 1296269,
              "node_id": "MDEwOlJlcG9zaXRvcnkxMjk2MjY5"
            }
          },
          "mergeable_state": "clean",
          "merged_by": {
            "login": "octocat",
            "id": 1,
            "node_id": "MDQ6VXNlcjE="
          },
          "comments": 10,
          "review_comments": 0,
          "maintainer_can_modify": true,
          "commits": 3,
          "additions": 100,
          "deletions": 3,
          "changed_files": 5
        }
      JSON
    end
  end

  it_behaves_like "a replicator that prevents overwriting new data with old", "github_pull_v1" do
    let(:old_body) do
      JSON.parse(<<~JSON)
        {
          "url": "https://api.github.com/repos/octocat/Hello-World/pulls/1347",
          "id": 1,
          "node_id": "MDExOlB1bGxSZXF1ZXN0MQ==",
          "number": 1347,
          "state": "open",
          "locked": true,
          "title": "Amazing new feature",
          "body": "Please pull these awesome changes in!",
          "active_lock_reason": "too heated",
          "created_at": "2011-01-26T19:01:12Z",
          "updated_at": "2011-01-26T19:01:12Z",
          "merge_commit_sha": "e5bd3914e2e596debea16f433f57875b5b90bcd6",
          "mergeable_state": "clean",
          "merged_by": null,
          "comments": 10,
          "review_comments": 0,
          "maintainer_can_modify": true,
          "commits": 3,
          "additions": 100,
          "deletions": 3,
          "changed_files": 5
        }
      JSON
    end
    let(:new_body) do
      JSON.parse(<<~JSON)
        {
          "url": "https://api.github.com/repos/octocat/Hello-World/pulls/1347",
          "id": 1,
          "node_id": "MDExOlB1bGxSZXF1ZXN0MQ==",
          "number": 1347,
          "state": "open",
          "locked": true,
          "title": "Amazing new feature",
          "body": "NEW BODY",
          "active_lock_reason": "too heated",
          "created_at": "2011-01-26T19:01:12Z",
          "updated_at": "2012-01-26T19:01:12Z",
          "merge_commit_sha": "e5bd3914e2e596debea16f433f57875b5b90bcd6",
          "mergeable_state": "clean",
          "merged_by": null,
          "comments": 10,
          "review_comments": 0,
          "maintainer_can_modify": true,
          "commits": 3,
          "additions": 100,
          "deletions": 3,
          "changed_files": 5
        }
      JSON
    end
  end

  it_behaves_like "a replicator that may have a minimal body", "github_pull_v1" do
    let(:body) do
      JSON.parse(<<~JSON)
        {
          "url": "https://api.github.com/repos/octocat/Hello-World/pulls/1347",
          "id": 1,
          "node_id": "MDExOlB1bGxSZXF1ZXN0MQ==",
          "number": 1347,
          "state": "open",
          "locked": true,
          "title": "Amazing new feature",
          "body": "Please pull these awesome changes in!",
          "active_lock_reason": "too heated",
          "created_at": "2011-01-26T19:01:12Z",
          "updated_at": "2011-01-26T19:01:12Z",
          "merge_commit_sha": "e5bd3914e2e596debea16f433f57875b5b90bcd6",
          "mergeable_state": "clean",
          "merged_by": null,
          "comments": 10,
          "review_comments": 0,
          "maintainer_can_modify": true,
          "commits": 3,
          "additions": 100,
          "deletions": 3,
          "changed_files": 5
        }
      JSON
    end
  end

  it_behaves_like "a replicator that deals with resources and wrapped events", "github_pull_v1" do
    let(:resource_json) { resource_in_envelope_json.fetch("pull_request") }
    let(:resource_in_envelope_json) do
      JSON.parse(<<~JSON)
        {
          "action": "created",
          "sender": {},
          "pull_request": {
            "url": "https://api.github.com/repos/octocat/Hello-World/pulls/1347",
            "id": 1,
            "node_id": "MDExOlB1bGxSZXF1ZXN0MQ==",
            "number": 1347,
            "state": "open",
            "locked": true,
            "title": "Amazing new feature",
            "body": "Please pull these awesome changes in!",
            "active_lock_reason": "too heated",
            "created_at": "2011-01-26T19:01:12Z",
            "updated_at": "2011-01-26T19:01:12Z",
            "merge_commit_sha": "e5bd3914e2e596debea16f433f57875b5b90bcd6",
            "mergeable_state": "clean",
            "merged_by": null,
            "comments": 10,
            "review_comments": 0,
            "maintainer_can_modify": true,
            "commits": 3,
            "additions": 100,
            "deletions": 3,
            "changed_files": 5
          }
        }
      JSON
    end
  end

  it_behaves_like "a replicator that uses enrichments", "github_pull_v1", stores_enrichment_column: false do
    let(:body) do
      JSON.parse(<<~JSON)
        {
          "url": "https://api.github.com/repos/my/CODE/pulls/1347",
          "id": 1,
          "node_id": "MDExOlB1bGxSZXF1ZXN0MQ==",
          "number": 1347,
          "state": "open",
          "locked": true,
          "title": "Amazing new feature",
          "active_lock_reason": "too heated",
          "created_at": "2011-01-26T19:01:12Z",
          "updated_at": "2011-01-26T19:01:12Z",
          "closed_at": "2011-01-26T19:01:12Z",
          "merged_at": "2011-01-26T19:01:12Z",
          "merge_commit_sha": "e5bd3914e2e596debea16f433f57875b5b90bcd6"
        }
      JSON
    end

    def stub_service_request
      body2 = body.dup
      body2[:merged_by] = {id: 55}
      return stub_request(:get, "https://api.github.com/repos/my/CODE/pulls/1347").
          to_return(status: 200, body: body2.to_json, headers: json_headers)
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.github.com/repos/my/CODE/pulls/1347").to_return(status: 404)
    end

    def assert_is_enriched(row)
      expect(row).to include(merged_by_id: 55)
    end
  end

  # This is tested through github_issue_v1
  # it_behaves_like "a replicator that verifies backfill secrets"

  it_behaves_like "a replicator that can backfill", "github_pull_v1" do
    let(:api_url) { "my/code" }
    let(:page1_response) do
      <<~JSON
        [
          {
            "url": "https://api.github.com/repos/octocat/Hello-World/pulls/1347",
            "id": 1,
            "node_id": "MDExOlB1bGxSZXF1ZXN0MQ==",
            "number": 1347,
            "state": "open",
            "locked": true,
            "title": "Amazing new feature",
            "body": "Please pull these awesome changes in!",
            "active_lock_reason": "too heated",
            "created_at": "2011-01-26T19:01:12Z",
            "updated_at": "2011-01-26T19:01:12Z",
            "merge_commit_sha": "e5bd3914e2e596debea16f433f57875b5b90bcd6",
            "mergeable_state": "clean",
            "merged_by": null,
            "comments": 10,
            "review_comments": 0,
            "maintainer_can_modify": true,
            "commits": 3,
            "additions": 100,
            "deletions": 3,
            "changed_files": 5
          },
          {
            "url": "https://api.github.com/repos/octocat/Hello-World/pulls/1347",
            "id": 2,
            "node_id": "MDExOlB1bGxSZXF1ZXN0MQ==",
            "number": 1347,
            "state": "open",
            "locked": true,
            "title": "Amazing new feature",
            "body": "Please pull these awesome changes in!",
            "active_lock_reason": "too heated",
            "created_at": "2011-01-26T19:01:12Z",
            "updated_at": "2011-01-26T19:01:12Z",
            "merge_commit_sha": "e5bd3914e2e596debea16f433f57875b5b90bcd6",
            "mergeable_state": "clean",
            "merged_by": null,
            "comments": 10,
            "review_comments": 0,
            "maintainer_can_modify": true,
            "commits": 3,
            "additions": 100,
            "deletions": 3,
            "changed_files": 5
          }
        ]
      JSON
    end
    let(:page2_response) do
      <<~JSON
        [
          {
            "url": "https://api.github.com/repos/octocat/Hello-World/pulls/1347",
            "id": 3,
            "node_id": "MDExOlB1bGxSZXF1ZXN0MQ==",
            "number": 1347,
            "state": "open",
            "locked": true,
            "title": "Amazing new feature",
            "body": "Please pull these awesome changes in!",
            "active_lock_reason": "too heated",
            "created_at": "2011-01-26T19:01:12Z",
            "updated_at": "2011-01-26T19:01:12Z",
            "merge_commit_sha": "e5bd3914e2e596debea16f433f57875b5b90bcd6",
            "mergeable_state": "clean",
            "merged_by": null,
            "comments": 10,
            "review_comments": 0,
            "maintainer_can_modify": true,
            "commits": 3,
            "additions": 100,
            "deletions": 3,
            "changed_files": 5
          }
        ]
      JSON
    end
    let(:expected_items_count) { 3 }
    def stub_service_requests
      return [
        stub_request(:get, "https://api.github.com/repos/my/code/pulls?per_page=100&state=all").
            to_return(
              status: 200,
              body: page1_response,
              headers: {
                "Content-Type" => "application/json",
                "Link" => '<https://api.github.com/repos/my/code/pulls?page=2>; rel="next"',
              },
            ),
        stub_request(:get, "https://api.github.com/repos/my/code/pulls?page=2").
            to_return(status: 200, body: page2_response, headers: json_headers),
      ]
    end

    def stub_empty_requests
      return [
        stub_request(:get, "https://api.github.com/repos/my/code/pulls?per_page=100&state=all").
            to_return(status: 200, body: "[]", headers: json_headers),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.github.com/repos/my/code/pulls?per_page=100&state=all").
          to_return(status: 400, body: "fuuu")
    end
  end

  it_behaves_like "a replicator that can backfill incrementally", "github_pull_v1" do
    let(:api_url) { "my/code" }
    let(:today) { Time.parse("2020-11-22T18:00:00Z") }
    let(:page1_response) do
      <<~JSON
        [
          {
            "url": "https://api.github.com/repos/octocat/Hello-World/pulls/1347",
            "id": 1,
            "node_id": "MDExOlB1bGxSZXF1ZXN0MQ==",
            "number": 1347,
            "state": "open",
            "locked": true,
            "title": "Amazing new feature",
            "body": "Please pull these awesome changes in!",
            "active_lock_reason": "too heated",
            "created_at": "2011-01-26T19:01:12Z",
            "updated_at": "2011-01-26T19:01:12Z",
            "merge_commit_sha": "e5bd3914e2e596debea16f433f57875b5b90bcd6",
            "mergeable_state": "clean",
            "merged_by": null,
            "comments": 10,
            "review_comments": 0,
            "maintainer_can_modify": true,
            "commits": 3,
            "additions": 100,
            "deletions": 3,
            "changed_files": 5
          }
        ]
      JSON
    end
    let(:page2_response) do
      <<~JSON
        [
          {
            "url": "https://api.github.com/repos/octocat/Hello-World/pulls/1347",
            "id": 2,
            "node_id": "MDExOlB1bGxSZXF1ZXN0MQ==",
            "number": 1347,
            "state": "open",
            "locked": true,
            "title": "Amazing new feature",
            "body": "Please pull these awesome changes in!",
            "active_lock_reason": "too heated",
            "created_at": "2011-01-26T19:01:12Z",
            "updated_at": "2011-01-26T19:01:12Z",
            "merge_commit_sha": "e5bd3914e2e596debea16f433f57875b5b90bcd6",
            "mergeable_state": "clean",
            "merged_by": null,
            "comments": 10,
            "review_comments": 0,
            "maintainer_can_modify": true,
            "commits": 3,
            "additions": 100,
            "deletions": 3,
            "changed_files": 5
          }
        ]
      JSON
    end
    let(:page3_response) do
      <<~JSON
        [
          {
            "url": "https://api.github.com/repos/octocat/Hello-World/pulls/1347",
            "id": 3,
            "node_id": "MDExOlB1bGxSZXF1ZXN0MQ==",
            "number": 1347,
            "state": "open",
            "locked": true,
            "title": "Amazing new feature",
            "body": "Please pull these awesome changes in!",
            "active_lock_reason": "too heated",
            "created_at": "2011-01-26T19:01:12Z",
            "updated_at": "2011-01-26T19:01:12Z",
            "merge_commit_sha": "e5bd3914e2e596debea16f433f57875b5b90bcd6",
            "mergeable_state": "clean",
            "merged_by": null,
            "comments": 10,
            "review_comments": 0,
            "maintainer_can_modify": true,
            "commits": 3,
            "additions": 100,
            "deletions": 3,
            "changed_files": 5
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
          stub_request(:get, "https://api.github.com/repos/my/code/pulls?" \
                             "per_page=100&since=2019-05-15T18:00:00Z&sort=updated&state=all",).
              to_return(status: 200, body: page3_response, headers: json_headers),
        ]
      end
      return [
        stub_request(:get, "https://api.github.com/repos/my/code/pulls?per_page=100&state=all").
            to_return(
              status: 200,
              body: page1_response,
              headers: {
                "Content-Type" => "application/json",
                "link" => '<https://api.github.com/repos/my/code/pulls?page=2>; rel="next"',
              },
            ),
        stub_request(:get, "https://api.github.com/repos/my/code/pulls?page=2").
            to_return(
              status: 200,
              body: page2_response,
              headers: {
                "Content-Type" => "application/json",
                "link" => '<https://api.github.com/repos/my/code/pulls?page=3>; rel="next"',
              },
            ),
        stub_request(:get, "https://api.github.com/repos/my/code/pulls?page=3").
            to_return(status: 200, body: page3_response, headers: json_headers),
      ]
    end
  end

  # Tested through github_issue
  # describe "webhook validation"
  # describe "state machine calculation"
end
