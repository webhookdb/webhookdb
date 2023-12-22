# frozen_string_literal: true

require "time"
require "webhookdb/convertkit"
require "webhookdb/replicator/convertkit_v1_mixin"

class Webhookdb::Replicator::ConvertkitTagV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::ConvertkitV1Mixin

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "convertkit_tag_v1",
      ctor: ->(sint) { Webhookdb::Replicator::ConvertkitTagV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "ConvertKit Tag",
      supports_backfill: true,
      api_docs_url: "https://developers.convertkit.com/#list-tags",
    )
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:created_at, TIMESTAMP, data_key: "created_at", index: true),
      Webhookdb::Replicator::Column.new(:name, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:total_subscriptions, INTEGER, from_enrichment: true),
    ]
  end

  def _timestamp_column_name
    return :created_at
  end

  def _resource_and_event(request)
    return request.body, nil
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:data] !~ Sequel[:excluded][:data]
  end

  def upsert_has_deps?
    return true
  end

  def _store_enrichment_body?
    return true
  end

  def _fetch_enrichment(resource, _event, _request)
    tag_id = resource.fetch("id")
    url = "https://api.convertkit.com/v3/tags/#{tag_id}/subscriptions?api_secret=#{self.service_integration.backfill_secret}"
    response = Webhookdb::Http.get(url, logger: self.logger, timeout: Webhookdb::Convertkit.http_timeout)
    data = response.parsed_response
    return data
  end

  def _fetch_backfill_page(_pagination_token, **_kwargs)
    # this endpoint does not have pagination support
    url = "https://api.convertkit.com/v3/tags?api_secret=#{self.service_integration.backfill_secret}"
    response = Webhookdb::Http.get(url, logger: self.logger, timeout: Webhookdb::Convertkit.http_timeout)
    data = response.parsed_response
    return data["tags"], nil
  end
end
