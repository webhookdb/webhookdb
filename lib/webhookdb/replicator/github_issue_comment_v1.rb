# frozen_string_literal: true

require "webhookdb/github"
require "webhookdb/replicator/github_repo_v1_mixin"

class Webhookdb::Replicator::GithubIssueCommentV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::GithubRepoV1Mixin

  def _mixin_backfill_url = "/issues/comments"
  def _mixin_webhook_events = ["Issue comments"]
  def _mixin_webhook_key = "comment"
  def _mixin_fine_grained_permission = "Issues"

  def _mixin_query_params(last_backfilled:)
    q = {}
    if last_backfilled
      q[:sort] = "updated"
      q[:since] = last_backfilled.utc.iso8601
    end
    return q
  end

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "github_issue_comment_v1",
      ctor: ->(sint) { Webhookdb::Replicator::GithubIssueCommentV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "GitHub Issue Comment",
      supports_webhooks: true,
      supports_backfill: true,
      api_docs_url: Webhookdb::Replicator::GithubRepoV1Mixin._api_docs_url("/issues/comments"),
    )
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:github_id, BIGINT, data_key: "id")
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(
        :issue_id,
        BIGINT,
        index: true,
        data_key: "issue_url",
        converter: Webhookdb::Replicator::Column.converter_from_regex('/issues/(\d+)$', dbtype: BIGINT),
      ),
      Webhookdb::Replicator::Column.new(:created_at, TIMESTAMP, index: true),
      Webhookdb::Replicator::Column.new(:updated_at, TIMESTAMP, index: true),
      Webhookdb::Replicator::Column.new(:user_id, BIGINT, index: true, data_key: ["user", "id"], optional: true),
      Webhookdb::Replicator::Column.new(:node_id, TEXT, index: true),
    ]
  end

  def _timestamp_column_name = :updated_at
end
