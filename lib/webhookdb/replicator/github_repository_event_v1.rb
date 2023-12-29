# frozen_string_literal: true

require "webhookdb/github"
require "webhookdb/replicator/github_repo_v1_mixin"

class Webhookdb::Replicator::GithubRepositoryEventV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::GithubRepoV1Mixin

  def _mixin_backfill_url = "/events"
  def _mixin_fine_grained_permission = "Contents"
  def _mixin_query_params(*) = {}

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "github_repository_event_v1",
      ctor: ->(sint) { Webhookdb::Replicator::GithubRepositoryEventV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "GitHub Repository Activity Event",
      supports_webhooks: false,
      supports_backfill: true,
      api_docs_url: Webhookdb::Replicator::GithubRepoV1Mixin._api_docs_url("/activity/events"),
    )
  end

  def calculate_webhook_state_machine = raise NotImplementedError

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:github_id, TEXT, data_key: "id")
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:type, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:created_at, TIMESTAMP, index: true),
      Webhookdb::Replicator::Column.new(:row_updated_at, TIMESTAMP, defaulter: :now, optional: true, index: true),
      Webhookdb::Replicator::Column.new(
        :actor_id, BIGINT, index: true, data_key: ["actor", "id"], optional: true,
      ),
    ]
  end

  def _timestamp_column_name = :row_updated_at
end
