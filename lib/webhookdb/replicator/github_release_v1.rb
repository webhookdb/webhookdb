# frozen_string_literal: true

require "webhookdb/github"
require "webhookdb/replicator/github_repo_v1_mixin"

class Webhookdb::Replicator::GithubReleaseV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::GithubRepoV1Mixin

  def _mixin_backfill_url = "/releases"
  def _mixin_webhook_events = ["Releases"]
  def _mixin_webhook_key = "release"
  def _mixin_fine_grained_permission = "Contents"
  def _mixin_query_params(*) = {}

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "github_release_v1",
      ctor: ->(sint) { Webhookdb::Replicator::GithubReleaseV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "GitHub Release",
      supports_webhooks: true,
      supports_backfill: true,
      api_docs_url: Webhookdb::Replicator::GithubRepoV1Mixin._api_docs_url("/releases/releases"),
    )
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:github_id, BIGINT, data_key: "id")
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:created_at, TIMESTAMP, index: true),
      Webhookdb::Replicator::Column.new(:published_at, TIMESTAMP, index: true),
      Webhookdb::Replicator::Column.new(:row_updated_at, TIMESTAMP, defaulter: :now, optional: true, index: true),
      Webhookdb::Replicator::Column.new(:node_id, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:tag_name, TEXT, index: true),
      Webhookdb::Replicator::Column.new(
        :author_id, BIGINT, index: true, data_key: ["author", "id"], optional: true,
      ),
    ]
  end

  def _timestamp_column_name = :row_updated_at
end
