# frozen_string_literal: true

require "webhookdb/github"
require "webhookdb/replicator/github_repo_v1_mixin"

class Webhookdb::Replicator::GithubPullV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::GithubRepoV1Mixin

  def _mixin_backfill_url = "/pulls"
  def _mixin_webhook_events = ["Pull requests"]
  def _mixin_webhook_key = "pull_request"
  def _mixin_fine_grained_permission = "Pull requests"

  def _mixin_query_params(last_backfilled:)
    q = {state: "all"}
    if last_backfilled
      q[:sort] = "updated"
      q[:since] = last_backfilled.utc.iso8601
    end
    return q
  end

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "github_pull_v1",
      ctor: ->(sint) { Webhookdb::Replicator::GithubPullV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "GitHub Pull Request",
      supports_webhooks: true,
      supports_backfill: true,
      api_docs_url: Webhookdb::Replicator::GithubRepoV1Mixin._api_docs_url("/pulls/pulls"),
    )
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:github_id, BIGINT, data_key: "id")
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:number, INTEGER, index: true),
      Webhookdb::Replicator::Column.new(:created_at, TIMESTAMP, index: true),
      Webhookdb::Replicator::Column.new(:updated_at, TIMESTAMP, index: true),
      Webhookdb::Replicator::Column.new(:closed_at, TIMESTAMP, index: true, optional: true),
      Webhookdb::Replicator::Column.new(:merged_at, TIMESTAMP, index: true, optional: true),
      Webhookdb::Replicator::Column.new(:state, TEXT),
      Webhookdb::Replicator::Column.new(:user_id, BIGINT, index: true, data_key: ["user", "id"], optional: true),
      Webhookdb::Replicator::Column.new(
        :merged_by_id,
        BIGINT,
        index: true,
        data_key: ["merged_by", "id"],
        optional: true,
      ),
      Webhookdb::Replicator::Column.new(
        :assignee_ids,
        BIGINT_ARRAY,
        index: true,
        data_key: "assignees",
        optional: true,
        converter: Webhookdb::Replicator::Column.converter_array_pluck("id", BIGINT),
      ),
      Webhookdb::Replicator::Column.new(
        :milestone_number,
        INTEGER,
        data_key: ["milestone", "number"],
        optional: true,
      ),
      Webhookdb::Replicator::Column.new(
        :label_ids,
        BIGINT_ARRAY,
        data_key: "labels",
        optional: true,
        converter: Webhookdb::Replicator::Column.converter_array_pluck("id", BIGINT),
      ),
      Webhookdb::Replicator::Column.new(:node_id, TEXT, index: true),
    ]
  end

  def _timestamp_column_name = :updated_at
end
