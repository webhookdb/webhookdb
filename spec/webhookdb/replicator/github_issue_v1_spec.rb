# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::GithubIssueV1, :db do
  let(:accept_json_contenttype) { "application/vnd.github+json" }
  let(:response_json_contenttype) { ["application/json; charset=utf-8", accept_json_contenttype].sample }

  it_behaves_like "a replicator", "github_issue_v1" do
    let(:body) do
      JSON.parse(<<~JSON)
        {
          "id": 1,
          "node_id": "MDU6SXNzdWUx",
          "url": "https://api.github.com/repos/octocat/Hello-World/issues/1347",
          "repository_url": "https://api.github.com/repos/octocat/Hello-World",
          "labels_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347/labels{/name}",
          "comments_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347/comments",
          "events_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347/events",
          "html_url": "https://github.com/octocat/Hello-World/issues/1347",
          "number": 1347,
          "state": "open",
          "title": "Found a bug",
          "body": "I'm having a problem with this.",
          "user": {
            "login": "octocat",
            "id": 1
          },
          "labels": [
            {
              "id": 208045946,
              "node_id": "MDU6TGFiZWwyMDgwNDU5NDY="
            }
          ],
          "assignee": {
            "login": "octocat",
            "id": 1
          },
          "assignees": [
            {
              "login": "octocat",
              "id": 1
            }
          ],
          "milestone": {
            "url": "https://api.github.com/repos/octocat/Hello-World/milestones/1",
            "html_url": "https://github.com/octocat/Hello-World/milestones/v1.0",
            "labels_url": "https://api.github.com/repos/octocat/Hello-World/milestones/1/labels",
            "id": 1002604,
            "node_id": "MDk6TWlsZXN0b25lMTAwMjYwNA==",
            "number": 1,
            "state": "open",
            "title": "v1.0",
            "description": "Tracking milestone for version 1.0",
            "creator": {
              "login": "octocat",
              "id": 1
            },
            "open_issues": 4,
            "closed_issues": 8,
            "created_at": "2011-04-10T20:09:31Z",
            "updated_at": "2014-03-03T18:58:10Z",
            "closed_at": "2013-02-12T13:22:01Z",
            "due_on": "2012-10-09T23:39:01Z"
          },
          "locked": true,
          "active_lock_reason": "too heated",
          "comments": 0,
          "pull_request": {
            "url": "https://api.github.com/repos/octocat/Hello-World/pulls/1347"
          },
          "closed_at": null,
          "created_at": "2011-04-22T13:33:48Z",
          "updated_at": "2011-04-22T13:33:48Z",
          "closed_by": {
            "login": "octocat",
            "id": 1
          },
          "author_association": "COLLABORATOR",
          "state_reason": "completed"
        }
      JSON
    end
  end

  it_behaves_like "a replicator that prevents overwriting new data with old", "github_issue_v1" do
    let(:old_body) do
      JSON.parse(<<~JSON)
        {
          "id": 1,
          "node_id": "MDU6SXNzdWUx",
          "url": "https://api.github.com/repos/octocat/Hello-World/issues/1347",
          "repository_url": "https://api.github.com/repos/octocat/Hello-World",
          "labels_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347/labels{/name}",
          "comments_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347/comments",
          "events_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347/events",
          "html_url": "https://github.com/octocat/Hello-World/issues/1347",
          "number": 1347,
          "state": "open",
          "title": "Found a bug",
          "body": "I'm having a problem with this.",
          "user": {
            "login": "octocat",
            "id": 1
          },
          "labels": [
            {
              "id": 208045946,
              "node_id": "MDU6TGFiZWwyMDgwNDU5NDY="
            }
          ],
          "assignee": {
            "login": "octocat",
            "id": 1
          },
          "assignees": [
            {
              "login": "octocat",
              "id": 1
            }
          ],
          "milestone": {
            "url": "https://api.github.com/repos/octocat/Hello-World/milestones/1",
            "html_url": "https://github.com/octocat/Hello-World/milestones/v1.0",
            "labels_url": "https://api.github.com/repos/octocat/Hello-World/milestones/1/labels",
            "id": 1002604,
            "node_id": "MDk6TWlsZXN0b25lMTAwMjYwNA==",
            "number": 1,
            "state": "open",
            "title": "v1.0",
            "description": "Tracking milestone for version 1.0",
            "creator": {
              "login": "octocat",
              "id": 1
            },
            "open_issues": 4,
            "closed_issues": 8,
            "created_at": "2011-04-10T20:09:31Z",
            "updated_at": "2014-03-03T18:58:10Z",
            "closed_at": "2013-02-12T13:22:01Z",
            "due_on": "2012-10-09T23:39:01Z"
          },
          "locked": true,
          "active_lock_reason": "too heated",
          "comments": 0,
          "pull_request": {
            "url": "https://api.github.com/repos/octocat/Hello-World/pulls/1347"
          },
          "closed_at": null,
          "created_at": "2011-04-22T13:33:48Z",
          "updated_at": "2011-04-22T13:33:48Z",
          "closed_by": {
            "login": "octocat",
            "id": 1
          },
          "author_association": "COLLABORATOR",
          "state_reason": "completed"
        }
      JSON
    end
    let(:new_body) do
      JSON.parse(<<~JSON)
        {
          "id": 1,
          "node_id": "MDU6SXNzdWUx",
          "url": "https://api.github.com/repos/octocat/Hello-World/issues/1347",
          "repository_url": "https://api.github.com/repos/octocat/Hello-World",
          "labels_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347/labels{/name}",
          "comments_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347/comments",
          "events_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347/events",
          "html_url": "https://github.com/octocat/Hello-World/issues/1347",
          "number": 1347,
          "state": "open",
          "title": "HAS BEEN UPDATED",
          "body": "I'm having a problem with this.",
          "user": {
            "login": "octocat",
            "id": 1
          },
          "labels": [
            {
              "id": 208045946,
              "node_id": "MDU6TGFiZWwyMDgwNDU5NDY="
            }
          ],
          "assignee": {
            "login": "octocat",
            "id": 1
          },
          "assignees": [
            {
              "login": "octocat",
              "id": 1
            }
          ],
          "milestone": {
            "url": "https://api.github.com/repos/octocat/Hello-World/milestones/1",
            "html_url": "https://github.com/octocat/Hello-World/milestones/v1.0",
            "labels_url": "https://api.github.com/repos/octocat/Hello-World/milestones/1/labels",
            "id": 1002604,
            "node_id": "MDk6TWlsZXN0b25lMTAwMjYwNA==",
            "number": 1,
            "state": "open",
            "title": "v1.0",
            "description": "Tracking milestone for version 1.0",
            "creator": {
              "login": "octocat",
              "id": 1
            },
            "open_issues": 4,
            "closed_issues": 8,
            "created_at": "2011-04-10T20:09:31Z",
            "updated_at": "2014-03-03T18:58:10Z",
            "closed_at": "2013-02-12T13:22:01Z",
            "due_on": "2012-10-09T23:39:01Z"
          },
          "locked": true,
          "active_lock_reason": "too heated",
          "comments": 0,
          "pull_request": {
            "url": "https://api.github.com/repos/octocat/Hello-World/pulls/1347"
          },
          "closed_at": null,
          "created_at": "2011-04-22T13:33:48Z",
          "updated_at": "2012-04-22T13:33:48Z",
          "closed_by": {
            "login": "octocat",
            "id": 1
          },
          "author_association": "COLLABORATOR",
          "state_reason": "completed"
        }
      JSON
    end
  end

  it_behaves_like "a replicator that may have a minimal body", "github_issue_v1" do
    let(:body) do
      JSON.parse(<<~JSON)
        {
          "id": 1,
          "node_id": "MDU6SXNzdWUx",
          "url": "https://api.github.com/repos/octocat/Hello-World/issues/1347",
          "repository_url": "https://api.github.com/repos/octocat/Hello-World",
          "labels_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347/labels{/name}",
          "comments_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347/comments",
          "events_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347/events",
          "html_url": "https://github.com/octocat/Hello-World/issues/1347",
          "number": 1347,
          "state": "open",
          "title": "Found a bug",
          "body": "I'm having a problem with this.",
          "locked": true,
          "active_lock_reason": "too heated",
          "comments": 0,
          "closed_at": null,
          "created_at": "2011-04-22T13:33:48Z",
          "updated_at": "2011-04-22T13:33:48Z",
          "author_association": "COLLABORATOR",
          "state_reason": "completed"
        }
      JSON
    end
  end
  it_behaves_like "a replicator that deals with resources and wrapped events", "github_issue_v1" do
    let(:resource_json) { resource_in_envelope_json.fetch("issue") }
    let(:resource_in_envelope_json) do
      JSON.parse(<<~JSON)
        {
          "action": "created",
          "sender": {},
          "issue": {
            "id": 1,
            "node_id": "MDU6SXNzdWUx",
            "url": "https://api.github.com/repos/octocat/Hello-World/issues/1347",
            "repository_url": "https://api.github.com/repos/octocat/Hello-World",
            "labels_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347/labels{/name}",
            "comments_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347/comments",
            "events_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347/events",
            "html_url": "https://github.com/octocat/Hello-World/issues/1347",
            "number": 1347,
            "state": "open",
            "title": "Found a bug",
            "body": "I'm having a problem with this.",
            "locked": true,
            "active_lock_reason": "too heated",
            "comments": 0,
            "closed_at": null,
            "created_at": "2011-04-22T13:33:48Z",
            "updated_at": "2011-04-22T13:33:48Z",
            "author_association": "COLLABORATOR",
            "state_reason": "completed"
          }
        }
      JSON
    end
  end

  it_behaves_like "a replicator that verifies backfill secrets" do
    let(:correct_creds_sint) do
      Webhookdb::Fixtures.service_integration.create(
        service_name: "github_issue_v1",
        api_url: "my/code",
        backfill_secret: "mytoken",
      )
    end
    let(:incorrect_creds_sint) do
      Webhookdb::Fixtures.service_integration.create(
        service_name: "github_issue_v1",
        api_url: "my/code",
        backfill_secret: "badtoken",
      )
    end
    let(:success_body) { "[]" }
    let(:failed_step_matchers) do
      {output: include("That access token "), prompt_is_secret: true}
    end
    def stub_service_request
      return stub_request(:get, "https://api.github.com/repos/my/code/issues?per_page=100&state=all").
          with(headers: {"Authorization" => "Bearer mytoken"}).
          to_return(status: 200, body: success_body, headers: {"Content-Type" => response_json_contenttype})
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.github.com/repos/my/code/issues?per_page=100&state=all").
          with(headers: {"Authorization" => "Bearer badtoken"}).
          to_return(status: 401, body: "", headers: {})
    end
  end
  it_behaves_like "a replicator that can backfill", "github_issue_v1" do
    let(:api_url) { "my/code" }
    let(:page1_response) do
      <<~JSON
        [
          {
            "id": 1,
            "node_id": "MDU6SXNzdWUx",
            "url": "https://api.github.com/repos/octocat/Hello-World/issues/1347",
            "repository_url": "https://api.github.com/repos/octocat/Hello-World",
            "labels_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347/labels{/name}",
            "comments_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347/comments",
            "events_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347/events",
            "html_url": "https://github.com/octocat/Hello-World/issues/1347",
            "number": 1347,
            "state": "open",
            "title": "Found a bug",
            "body": "I'm having a problem with this.",
            "locked": true,
            "active_lock_reason": "too heated",
            "comments": 0,
            "closed_at": null,
            "created_at": "2011-04-22T13:33:48Z",
            "updated_at": "2011-04-22T13:33:48Z",
            "author_association": "COLLABORATOR",
            "state_reason": "completed"
          },
          {
            "id": 2,
            "node_id": "MDU6SXNzdWUx",
            "url": "https://api.github.com/repos/octocat/Hello-World/issues/1347",
            "repository_url": "https://api.github.com/repos/octocat/Hello-World",
            "labels_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347/labels{/name}",
            "comments_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347/comments",
            "events_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347/events",
            "html_url": "https://github.com/octocat/Hello-World/issues/1347",
            "number": 1348,
            "state": "open",
            "title": "Found a bug",
            "body": "I'm having a problem with this.",
            "locked": true,
            "active_lock_reason": "too heated",
            "comments": 0,
            "closed_at": null,
            "created_at": "2011-04-22T13:33:48Z",
            "updated_at": "2011-04-22T13:33:48Z",
            "author_association": "COLLABORATOR",
            "state_reason": "completed"
          }
        ]
      JSON
    end
    let(:page2_response) do
      <<~JSON
        [
          {
            "id": 3,
            "node_id": "MDU6SXNzdWUx",
            "url": "https://api.github.com/repos/octocat/Hello-World/issues/1347",
            "repository_url": "https://api.github.com/repos/octocat/Hello-World",
            "labels_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347/labels{/name}",
            "comments_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347/comments",
            "events_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347/events",
            "html_url": "https://github.com/octocat/Hello-World/issues/1347",
            "number": 1349,
            "state": "open",
            "title": "Found a bug",
            "body": "I'm having a problem with this.",
            "locked": true,
            "active_lock_reason": "too heated",
            "comments": 0,
            "closed_at": null,
            "created_at": "2011-04-22T13:33:48Z",
            "updated_at": "2011-04-22T13:33:48Z",
            "author_association": "COLLABORATOR",
            "state_reason": "completed"
          }
        ]
      JSON
    end
    let(:expected_items_count) { 3 }
    def stub_service_requests
      return [
        stub_request(:get, "https://api.github.com/repos/my/code/issues?per_page=100&state=all").
            with(
              headers: {
                "Authorization" => "Bearer bfsek",
                "Accept" => accept_json_contenttype,
                "X-Github-Api-Version" => "2022-11-28",
              },
            ).
            to_return(
              status: 200,
              body: page1_response,
              headers: {
                "Content-Type" => response_json_contenttype,
                "Link" => '<https://api.github.com/repos/my/code/issues?page=2>; rel="next"',
              },
            ),
        stub_request(:get, "https://api.github.com/repos/my/code/issues?page=2").
            to_return(
              status: 200,
              body: page2_response,
              headers: {"Content-Type" => response_json_contenttype},
            ),
      ]
    end

    def stub_empty_requests
      return [
        stub_request(:get, "https://api.github.com/repos/my/code/issues?per_page=100&state=all").
            to_return(
              status: 200,
              body: "[]",
              headers: {"Content-Type" => response_json_contenttype},
            ),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.github.com/repos/my/code/issues?per_page=100&state=all").
          to_return(status: 400, body: "fuuu")
    end
  end

  it_behaves_like "a replicator that can backfill incrementally", "github_issue_v1" do
    let(:api_url) { "my/code" }
    let(:today) { Time.parse("2020-11-22T18:00:00Z") }
    let(:page1_response) do
      <<~JSON
        [
          {
            "id": 1,
            "node_id": "MDU6SXNzdWUx",
            "url": "https://api.github.com/repos/octocat/Hello-World/issues/1347",
            "repository_url": "https://api.github.com/repos/octocat/Hello-World",
            "labels_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347/labels{/name}",
            "comments_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347/comments",
            "events_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347/events",
            "html_url": "https://github.com/octocat/Hello-World/issues/1347",
            "number": 1347,
            "state": "open",
            "title": "Found a bug",
            "body": "I'm having a problem with this.",
            "locked": true,
            "active_lock_reason": "too heated",
            "comments": 0,
            "closed_at": null,
            "created_at": "2011-04-22T13:33:48Z",
            "updated_at": "2011-04-22T13:33:48Z",
            "author_association": "COLLABORATOR",
            "state_reason": "completed"
          }
        ]
      JSON
    end
    let(:page2_response) do
      <<~JSON
        [
          {
            "id": 3,
            "node_id": "MDU6SXNzdWUx",
            "url": "https://api.github.com/repos/octocat/Hello-World/issues/1347",
            "repository_url": "https://api.github.com/repos/octocat/Hello-World",
            "labels_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347/labels{/name}",
            "comments_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347/comments",
            "events_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347/events",
            "html_url": "https://github.com/octocat/Hello-World/issues/1347",
            "number": 1349,
            "state": "open",
            "title": "Found a bug",
            "body": "I'm having a problem with this.",
            "locked": true,
            "active_lock_reason": "too heated",
            "comments": 0,
            "closed_at": null,
            "created_at": "2011-04-22T13:33:48Z",
            "updated_at": "2011-04-22T13:33:48Z",
            "author_association": "COLLABORATOR",
            "state_reason": "completed"
          }
        ]
      JSON
    end
    let(:page3_response) do
      <<~JSON
        [
          {
            "id": 5,
            "node_id": "MDU6SXNzdWUx",
            "url": "https://api.github.com/repos/octocat/Hello-World/issues/1347",
            "repository_url": "https://api.github.com/repos/octocat/Hello-World",
            "labels_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347/labels{/name}",
            "comments_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347/comments",
            "events_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347/events",
            "html_url": "https://github.com/octocat/Hello-World/issues/1347",
            "number": 1341,
            "state": "open",
            "title": "Found a bug",
            "body": "I'm having a problem with this.",
            "locked": true,
            "active_lock_reason": "too heated",
            "comments": 0,
            "closed_at": null,
            "created_at": "2011-04-22T13:33:48Z",
            "updated_at": "2011-04-22T13:33:48Z",
            "author_association": "COLLABORATOR",
            "state_reason": "completed"
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
          stub_request(:get, "https://api.github.com/repos/my/code/issues?" \
                             "per_page=100&since=2019-05-15T18:00:00Z&sort=updated&state=all",).
              to_return(status: 200, body: page3_response, headers: {"Content-Type" => response_json_contenttype}),
        ]
      end
      return [
        stub_request(:get, "https://api.github.com/repos/my/code/issues?per_page=100&state=all").
            to_return(
              status: 200,
              body: page1_response,
              headers: {
                "Content-Type" => response_json_contenttype,
                "link" => '<https://api.github.com/repos/my/code/issues?page=2>; rel="next"',
              },
            ),
        stub_request(:get, "https://api.github.com/repos/my/code/issues?page=2").
            to_return(
              status: 200,
              body: page2_response,
              headers: {
                "Content-Type" => response_json_contenttype,
                "link" => '<https://api.github.com/repos/my/code/issues?page=3>; rel="next"',
              },
            ),
        stub_request(:get, "https://api.github.com/repos/my/code/issues?page=3").
            to_return(
              status: 200,
              body: page3_response,
              headers: {"Content-Type" => response_json_contenttype},
            ),
      ]
    end
  end

  describe "webhook validation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "github_issue_v1") }
    let(:svc) { Webhookdb::Replicator.create(sint) }

    it "returns a 401 if there is no Authorization header" do
      expect(svc.webhook_response(fake_request)).to have_attributes(status: 401, reason: "missing sha256")
    end

    it "returns a 401 for an invalid Authorization header" do
      sint.update(webhook_secret: "It's a Secret to Everybody")
      req = fake_request(input: "Hello, World!")
      req.add_header("HTTP_X_HUB_SIGNATURE_256", "sha256=BADSHA")
      expect(svc.webhook_response(req)).to have_attributes(status: 401, reason: "invalid sha256")
    end

    it "returns a 401 if no webhook secret is set" do
      sint.update(webhook_secret: nil)
      req = fake_request(input: "Hello, World!")
      req.add_header("HTTP_X_HUB_SIGNATURE_256", "sha256=BADSHA")
      expect(svc.webhook_response(req)).to have_attributes(
        status: 409, reason: "no secret set, run `webhookdb integration setup`",
      )
    end

    it "returns a 202 with a valid Authorization header" do
      sint.update(webhook_secret: "It's a Secret to Everybody")
      req = fake_request(input: "Hello, World!")
      req.add_header("HTTP_X_HUB_SIGNATURE_256",
                     "sha256=757107ea0eb2509fc211221cce984b8a37570b6d7586c22c46f4379c8b043e17",)
      expect(svc.webhook_response(req)).to have_attributes(status: 202)
    end
  end

  describe "state machine calculation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "github_issue_v1", api_url: "") }
    let(:svc) { Webhookdb::Replicator.create(sint) }

    describe "calculate_webhook_state_machine" do
      it "asks for the repository name" do
        sm = sint.replicator.calculate_webhook_state_machine
        expect(sm).to have_attributes(
          prompt: eq("Repository name:"),
          prompt_is_secret: be(false),
          post_to_url: end_with("/service_integrations/#{sint.opaque_id}/transition/repo_name"),
          output: match("First we need the full repository name"),
        )
      end

      it "reasks for repo name if it is not of the right form" do
        sint.api_url = "foobar"
        sm = sint.replicator.calculate_webhook_state_machine
        expect(sm).to have_attributes(
          prompt: eq("Repository name:"),
          prompt_is_secret: be(false),
          post_to_url: end_with("/service_integrations/#{sint.opaque_id}/transition/repo_name"),
          output: match("That repository is not valid"),
        )
      end

      it "asks for webhook secret if api_url is set" do
        sint.api_url = "my/code"
        sm = sint.replicator.calculate_webhook_state_machine
        expect(sm).to have_attributes(
          prompt: eq("Paste or type your Webhook Secret here:"),
          prompt_is_secret: be(true),
          post_to_url: end_with("/service_integrations/#{sint.opaque_id}/transition/webhook_secret"),
          output: match("Which events would you like to trigger this webhook"),
        )
      end

      it "confirms reciept of webhook secret, returns org database info" do
        sint.api_url = "my/code"
        sint.webhook_secret = "mysekret"
        sm = sint.replicator.calculate_webhook_state_machine
        expect(sm).to have_attributes(
          needs_input: be(false),
          complete: be(true),
          output: match("Great! WebhookDB is now listening for GitHub Issue webhooks."),
        )
      end
    end

    describe "when processing the repo_name field" do
      it "sets api_url and returns the webhook state machine" do
        sm = sint.replicator.process_state_change("repo_name", "my/code")
        expect(sm).to have_attributes(prompt: "Paste or type your Webhook Secret here:")
        expect(sint).to have_attributes(api_url: "my/code")
      end
    end

    describe "calculate_backfill_state_machine" do
      def stub_public_repo_req(status)
        stub_request(:head, "https://github.com/my/code").
          to_return(status:, body: "", headers: {})
      end

      it "prompts for the api url if not set" do
        sm = sint.replicator.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          prompt_is_secret: false,
          post_to_url: end_with("/service_integrations/#{sint.opaque_id}/transition/api_url"),
          output: include("You are about to start replicating GitHub Issues"),
        )
      end

      it "asks for backfill secret (public repo)" do
        sint.api_url = "my/code"
        stub_public_repo_req(200)
        sm = sint.replicator.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          prompt: "Paste or type your Personal access token here:",
          prompt_is_secret: true,
          post_to_url: end_with("/service_integrations/#{sint.opaque_id}/transition/backfill_secret"),
          output: include("under 'Scopes', ensure repo->public_repo is checked,\nsince my/code is public"),
        )
      end

      it "asks for backfill secret (private repo)" do
        sint.api_url = "my/code"
        stub_public_repo_req(404)
        sm = sint.replicator.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          prompt: "Paste or type your Personal access token here:",
          prompt_is_secret: true,
          post_to_url: end_with("/service_integrations/#{sint.opaque_id}/transition/backfill_secret"),
          output: include("under 'Scopes', ensure repo is checked,\nsince my/code is private"),
        )
      end

      it "returns a completed step" do
        sint.api_url = "my/code"
        sint.backfill_secret = "sekret"
        res = stub_request(:get, "https://api.github.com/repos/my/code/issues?per_page=100&state=all").
          to_return(status: 200, body: "[]", headers: {"Content-Type" => response_json_contenttype})
        sm = sint.replicator.calculate_backfill_state_machine
        expect(res).to have_been_made
        expect(sm).to have_attributes(
          needs_input: false,
          complete: true,
          output: match("Great! We are going to start backfilling your GitHub Issues."),
        )
      end
    end
  end
end
