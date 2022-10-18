# frozen_string_literal: true

require "time"
require "webhookdb/convertkit"
require "webhookdb/replicator/convertkit_v1_mixin"

class Webhookdb::Replicator::ConvertkitBroadcastV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::ConvertkitV1Mixin

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "convertkit_broadcast_v1",
      ctor: ->(sint) { Webhookdb::Replicator::ConvertkitBroadcastV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "ConvertKit Broadcast",
    )
  end

  def calculate_create_state_machine
    return self.calculate_backfill_state_machine
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:click_rate, DECIMAL, from_enrichment: true, optional: true),
      Webhookdb::Replicator::Column.new(:created_at, TIMESTAMP, index: true),
      Webhookdb::Replicator::Column.new(:open_rate, DECIMAL, from_enrichment: true, optional: true),
      Webhookdb::Replicator::Column.new(:progress, DECIMAL, from_enrichment: true, optional: true),
      Webhookdb::Replicator::Column.new(:recipients, INTEGER, from_enrichment: true, optional: true),
      Webhookdb::Replicator::Column.new(:show_total_clicks, BOOLEAN, from_enrichment: true, optional: true),
      Webhookdb::Replicator::Column.new(:status, TEXT, from_enrichment: true, optional: true),
      Webhookdb::Replicator::Column.new(:subject, TEXT),
      Webhookdb::Replicator::Column.new(:total_clicks, INTEGER, from_enrichment: true, optional: true),
      Webhookdb::Replicator::Column.new(:unsubscribes, INTEGER, from_enrichment: true, optional: true),
    ]
  end

  def _resource_and_event(request)
    return request.body, nil
  end

  def _timestamp_column_name
    return :created_at
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:data] !~ Sequel[:excluded][:data]
  end

  def _store_enrichment_body?
    return true
  end

  def _fetch_enrichment(resource, _event, _request)
    broadcast_id = resource.fetch("id")
    url = "https://api.convertkit.com/v3/broadcasts/#{broadcast_id}/stats?api_secret=#{self.service_integration.backfill_secret}"
    response = Webhookdb::Http.get(url, logger: self.logger)
    data = response.parsed_response
    return data.dig("broadcast", "stats") || {}
  end

  def _fetch_backfill_page(_pagination_token, **_kwargs)
    # this endpoint does not have pagination support
    url = "https://api.convertkit.com/v3/broadcasts?api_secret=#{self.service_integration.backfill_secret}"
    response = Webhookdb::Http.get(url, logger: self.logger)
    data = response.parsed_response
    return data["broadcasts"], nil
  end
end
